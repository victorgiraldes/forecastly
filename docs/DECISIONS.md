# Engineering Decisions & Trade-offs

This document records the engineering decisions behind Forecastly and the trade-offs each one accepts. The goal is not to claim these are the only valid choices, but to make the reasoning explicit and defensible.

## How to read this

Each decision follows the same shape:

- **Context** — the constraint or requirement that forced a choice.
- **Decision** — what was done.
- **Trade-off** — what was deliberately given up.
- **Evolution** — the known limitation and the cheap path to change it later.

A recurring principle runs through all of them: **scope the engineering effort to the problem.** This is a focused weather-lookup challenge, so the bar for adding infrastructure, abstraction, or test ceremony is "does it pay for itself here?" — not "is it best practice in general?"

---

## 1. No database; minimal Rails generation

- **Context:** the only state the app needs is a forecast cache that expires in 30 minutes. There are no users, searches, addresses, or records to persist.
- **Decision:** generate Rails with Active Record and the Solid stack skipped (`--skip-active-record --skip-solid`, plus Action Mailer/Cable/Storage/Text, Kamal, Thruster, Active Job).
- **Trade-off:** faster boot and far less surface area, at the cost of no built-in persistence and a per-process default cache.
- **Note:** the unused default scaffold was also trimmed after generation — `jbuilder` (no JSON API; HTML only), the PWA manifest/service-worker stubs (their routes ship commented out), and the empty Stimulus layer (no controllers defined). Turbo is kept for navigation (Decision 4). The intent is the same: carry only what this app uses.
- **Evolution:** a shared cache is one line of config away (see Decision 6). Nothing in the domain code assumes a database, so adding one later is additive, not a rewrite.

## 2. Two direct providers (Zippopotam.us + Nominatim) instead of the `geocoder` gem

- **Context:** the requirement is "accept an address as input," and the forecast is keyed by ZIP. So the app must resolve both bare ZIP codes and free-text addresses to coordinates. The `geocoder` gem abstracts many providers, but postal-code support varies by provider, country, and data source.
- **Decision:** route by input type — `ZipCodeLookupService` (Zippopotam.us) for 5-digit ZIPs, `AddressLookupService` (OpenStreetMap Nominatim) for free-text addresses. Both are called directly, key-less, behind their own service.
- **Why not Zippopotam alone:** Zippopotam does ZIP→place (`/us/90210`) and even city/state→ZIPs (`/us/ca/beverly hills`), but it has no street-level geocoding — it resolves postal codes and place names, not house numbers and streets. It cannot resolve "1600 Amphitheatre Parkway, Mountain View, CA", so the address path needs a real geocoder (Nominatim).
- **Trade-off:** two integrations instead of one gem, in exchange for explicit, predictable, easy-to-test behavior and a provider chosen per input type. Nominatim carries a usage policy (descriptive `User-Agent`, light request rates) that is respected here but would warrant a dedicated geocoder at production volume.
- **Note:** an earlier version accepted ZIP only and documented *not* using a geocoder. Re-reading the requirement ("address as input"), I added the address path — the hybrid keeps the precise ZIP lookup and adds real address geocoding without throwing away the original work.
- **Evolution:** each resolver is a seam; swapping providers or adding multi-country support touches one service, not the orchestration or controller.

## 3. Faraday + dependency injection instead of a weather gem

- **Context:** weather data needs an HTTP integration. Weather-specific gems tend to be provider-locked, key-bound, or unmaintained.
- **Decision:** call the external APIs with Faraday directly, and inject the HTTP client (`client:`) and cache (`cache:`) as dependencies.
- **Why Faraday:** its pluggable adapter layer was the deciding factor — the HTTP backend (Net::HTTP, Typhoeus, async, etc.) can be swapped, and cross-cutting concerns (retries, logging, instrumentation) added as middleware, all behind one stable API without rewriting the call sites. The three lookup services share that plumbing through the `ExternalApi` mixin.
- **Trade-off:** a little more explicit code than a gem, in exchange for a transparent, debuggable integration and tests that need no network and no HTTP mocking library.
- **Evolution:** the injected client plus Faraday's adapter/middleware model means a different backend, retry-with-backoff, or instrumentation can be wired in at the boundary without touching the service logic.

## 4. Query parameter instead of a path segment (works without JavaScript)

- **Context:** the forecast lookup needs a URL. An early version used `GET /forecasts/:zip_code`.
- **Decision:** expose it as `GET /forecast?location=90210` (the `location` field accepts a ZIP or an address).
- **Why it changed:** the path-segment version forced the search form to build the URL in JavaScript, so the app broke entirely with scripting disabled. A forecast lookup is conceptually a *search*, not a stored resource, so a query parameter models it more honestly **and** lets the form be plain HTML (`<form method="get" action="/forecast">`).
- **Trade-off:** a less "RESTful-looking" URL, in exchange for working without JavaScript and removing a client-side dependency. Hotwire still enhances navigation when JS is present.
- **Note:** this is a decision I revisited after finding a flaw in my own first design — the resilience win outweighed URL aesthetics.

## 5. Two-level cache: location by query, forecast by ZIP

- **Context:** the requirement is to cache "forecast details" for 30 minutes per ZIP and indicate cache hits. But the input can be a free-text address, which different users spell differently ("1 Main St" vs "1 Main Street").
- **Decision:** cache in two layers — the resolved **location** keyed by the normalized query (so repeating the same text skips the ZIP/geocoding call), and the **forecast** keyed by the resolved **ZIP** for 30 minutes (so spellings that resolve to the same ZIP — and plain ZIP searches — share one entry). The `from_cache` flag reflects the forecast cache and is computed at the boundary via `merge`, never stored inside the cached value.
- **Trade-off:** two cache entries and two TTLs instead of one. An earlier version keyed everything by the raw query, which let a cache hit skip *every* call — but it fragmented the cache across address spellings and didn't honour "by ZIP." Keying the forecast by ZIP fixes both; the location cache recovers most of the "skip the call" benefit for repeated queries. A location without a ZIP falls back to a coordinate key.
- **Evolution:** TTLs and key strategy live in one service — the location TTL is long (locations are stable), the forecast TTL is the required 30 minutes.

## 6. Redis cache store in production, with an ENV fallback

- **Context:** the default per-process cache is not shared across instances, which breaks the "30 minutes for all subsequent requests" guarantee under horizontal scaling.
- **Decision:** in production, use `:redis_cache_store` when `REDIS_URL` is set; otherwise fall back to `:memory_store`.
- **Trade-off:** one extra dependency (`redis`), in exchange for a cache that is correct across instances. Solid Cache was skipped because it is Active Record-backed and this app has no database.
- **Evolution:** the store is reached through Rails' cache abstraction, so swapping to Memcached or adding a connection pool/error handler is config-only.

## 7. Explicit HTTP timeouts; errors degrade to a friendly result

- **Context:** without timeouts, Faraday falls back to the adapter defaults (effectively unbounded connection time), so a slow upstream can hang a web worker.
- **Decision:** set `open_timeout` and `read_timeout` per request. Timeouts and connection failures raise `Faraday::Error`, which is rescued, logged, and turned into `nil`. This plumbing — timeouts, JSON parsing, and error handling — lives in a shared `ExternalApi` mixin, so the three HTTP services don't duplicate it.
- **Trade-off:** a fixed timeout can cut off a genuinely slow-but-valid response; the chosen values favor a responsive UI over rare slow successes.
- **Evolution:** retry-with-backoff is the natural next step (deferred below) — but timeouts come first, because there is no point retrying a call whose first attempt is unbounded.

## 8. Lightweight error differentiation instead of a Result object

- **Context:** services signal failure by returning `nil`, which the controller turned into a single generic message.
- **Decision:** the controller distinguishes the two cases the *user* can act on — empty input ("enter an address or US ZIP code") versus an input that could not be resolved ("try again").
- **Trade-off:** this does not type every internal failure (not-found vs API-down vs timeout are still merged). A full `Result(value, error)` object would model all of them, but for a UI with two meaningful user-facing states that would be over-engineering.
- **Evolution:** if the UI or observability needs finer reasons, the services can return a small `Result` with a reason without changing the controller's contract much.

## 9. An incomplete forecast is treated as a failure

- **Context:** a `200 OK` from the weather API can still arrive with missing temperature fields.
- **Decision:** `WeatherForecastService` returns `nil` if current/high/low are absent, so an incomplete forecast is never rendered or cached.
- **Trade-off:** "all three temperatures or nothing" is stricter than showing partial data, but it guarantees the UI never displays blank readings or caches a half-result for 30 minutes.
- **Evolution:** if partial display is ever desirable, the normalization step is the single place to relax this.

## 10. Service objects for orchestration

- **Context:** the flow has distinct responsibilities — normalize input, resolve a location (ZIP or address), fetch weather — plus caching and routing.
- **Decision:** single-purpose services with `.call` class methods — `ZipCodeLookupService`, `AddressLookupService`, `WeatherForecastService`, and `ForecastLookupService` as the orchestrator that routes and caches; the controller stays thin.
- **Trade-off:** a few more files than cramming logic into the controller, in exchange for isolated, independently testable units.
- **Evolution:** each service is a seam for swapping providers, adding instrumentation, or composing new flows.

## 11. Test doubles via DI, plus a thin WebMock contract layer

- **Context:** tests must be fast, deterministic, and offline — but a fully doubled HTTP client never exercises the real request/response path.
- **Decision:** unit specs inject fake clients and a fake cache (services, request flow, rendered views). On top of that, contract specs in `spec/contracts/` run the real Faraday client against WebMock-stubbed endpoints, asserting the request (URL, params, the Nominatim `User-Agent`) and the parsing of a realistic response.
- **Trade-off:** WebMock adds a test dependency, but it closes the gap the DI doubles leave: a wrong request or a changed upstream response shape is now caught locally. The contract specs are deliberately thin — one happy path per provider, a tripwire rather than full branch coverage.
- **Note:** the suite runs on **RSpec**, not the default Minitest. The empty `test/` scaffold from `rails new` was removed and `rails/test_unit/railtie` left out, so there is one test framework and one source of truth (`spec/`); CI and the local `bin/ci` both run `bundle exec rspec`.
- **Evolution:** if an upstream changes, the canned bodies can be refreshed from real responses (or recorded with VCR) without touching the unit specs.

## 12. SimpleCov with a 90% coverage floor

- **Context:** coverage is a useful regression signal, but it is easy to treat the number as a goal in itself.
- **Decision:** add SimpleCov with `minimum_coverage line: 90`, enforced in CI, with the HTML report uploaded as a build artifact. The suite currently sits at 100%.
- **Trade-off:** the gate is a *floor*, not proof of correctness — high coverage does not mean the assertions are good. The threshold is set well below the current number on purpose so it stays a guardrail rather than a brittle tripwire that fails on every small change.
- **Note:** the per-request Faraday setters (timeouts, the Nominatim `User-Agent`) are exercised by the contract specs (Decision 11), which run the real client — so they are covered through behavior, not by asserting attribute assignments.

## 13. A single free-text field for both address and ZIP

- **Context:** the field must accept a 5-digit ZIP *or* a free-text address, so digit-only constraints no longer fit.
- **Decision:** one `type="text"` field named `location`, with `required` to block empty submits. An earlier ZIP-only version used `inputmode="numeric"`, `pattern="\d{5}"`, and `maxlength="5"`; those were removed once the field had to accept letters, spaces, and punctuation.
- **Trade-off:** less client-side validation than a strict ZIP field, in exchange for accepting the broader input the requirement asks for. `type="number"` was never an option — it mangles leading zeros (`01234`) and is meaningless for addresses.
- **Evolution:** routing and resolution on the server (`ForecastLookupService` → ZIP or address resolver) are the source of truth; the field stays deliberately permissive.

## 14. CI as a quality and security gate

- **Context:** a small app still benefits from automated guardrails.
- **Decision:** CI runs Brakeman (Rails security scan), bundler-audit (gem CVEs), importmap audit (JS deps), RuboCop (omakase style), and the RSpec suite with the coverage gate.
- **Trade-off:** a few minutes of CI time, in exchange for catching style, security, and coverage regressions before review.
- **Evolution:** dependency updates are already automated via Dependabot; observability and rate limiting (below) would be the next gates for a production deployment.

---

## Deliberately deferred (and why)

Ordered by operational risk, not by feature appeal — this ordering is itself a decision:

1. **Retry with backoff** for transient upstream failures — higher value than new features; deferred only because timeouts (Decision 7) close the more urgent risk first.
2. **Observability** around external-API failures (metrics/structured logs beyond `Rails.logger.error`) — needed before this runs in production for real.
3. **Rate-limit protection** — Rails 8 ships `rate_limit`, and now that a cache store exists it is feasible; deferred as out of scope for the challenge.
4. **Negative caching** for repeated invalid/not-found lookups — a small optimization, low risk if absent.
5. **ZIP+4 and multi-country search** — product scope, not infrastructure; the provider seam (Decision 2) keeps these open. (Free-text US address input is already supported.)

Each of these is a conscious "not now," not an oversight.

---

## Anticipated questions

- **"Why does the search work as a query parameter and not a clean path?"** — A lookup is a search, not a resource, so the query parameter is the more honest model — and it makes the form work without JavaScript. See Decision 4.
- **"What happens if the same ZIP is requested many times?"** — The cache absorbs it. The remaining blind spot is a cache stampede: several concurrent misses for the same ZIP each hit upstream. A write lock would fix it if it became a problem.
- **"How would you handle a slow or down provider?"** — Timeouts cap each call (Decision 7); failures are rescued into a friendly "try again." Retry-with-backoff is the documented next step.
- **"Why no test for the real HTTP call?"** — Dependency injection keeps tests fast and offline (Decision 11); the trade-off is acknowledged, and a thin contract test is the planned tripwire.
- **"Is the coverage gate meaningful?"** — It is a floor (90%) that catches regressions, not a correctness proof; it is set below the current number on purpose to avoid brittleness. See Decision 12.
- **"Why Redis and not Solid Cache?"** — Solid Cache is Active Record-backed and this app has no database; Redis is a lighter fit for a shared cache. See Decision 6.
- **"You documented not using a geocoder, but you geocode addresses — why?"** — The requirement asks for address input, so I added a dedicated address resolver (Nominatim) alongside the ZIP one, rather than adopting the `geocoder` gem's provider-dependent abstraction. ZIP and address each use the provider best suited to them. See Decision 2.
- **"Are these public APIs production-grade?"** — They are solid for this scope and run with zero keys, which keeps the project reproducible for a reviewer. Each free tier has limits — Nominatim's usage policy, Open-Meteo's non-commercial tier, Zippopotam's lack of an SLA. At commercial scale each would be swapped for an SLA-backed provider; because coordinates are the common contract between geocoding and weather, that is a per-service change, not a rewrite.
