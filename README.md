# Forecastly

Forecastly is a minimal Rails application that retrieves weather forecast data for a given US address or ZIP code.

The application allows users to enter an address or ZIP code, resolves it to a location, fetches the weather forecast, caches the result for 30 minutes, and indicates whether the response came from cache.

---

## Features

- Search weather forecast by US address or ZIP code
- Resolve ZIP codes via Zippopotam.us and addresses via OpenStreetMap (Nominatim)
- Retrieve weather forecast data from Open-Meteo
- Display current temperature
- Display daily high and low temperatures
- Cache forecast results by ZIP code for 30 minutes
- Indicate whether the result came from cache
- Handle invalid ZIP codes and external API failures gracefully
- Work without JavaScript (the search form is plain HTML)

---

## Requirements

- Ruby 3.3
- Rails 8.x
- Bundler

---

## Project setup

This project was generated with a minimal Rails configuration:

```bash
rails new forecastly \
  --skip-active-record \
  --skip-solid \
  --skip-action-mailer \
  --skip-action-mailbox \
  --skip-action-text \
  --skip-active-storage \
  --skip-action-cable \
  --skip-kamal \
  --skip-thruster \
  --skip-active-job
```

The goal was to keep the application focused on the challenge requirements and avoid unnecessary infrastructure.

---

## Installation

Install the dependencies:

```bash
bundle install
```

Start the Rails server:

```bash
bin/rails server
```

Then open:

```text
http://localhost:3000
```

---

## Usage

Enter a US ZIP code or a full address, for example:

```text
90210
1600 Amphitheatre Parkway, Mountain View, CA
Empire State Building, New York
```

The application will display the forecast for the corresponding location.

Example result:

```text
Beverly Hills, California
ZIP Code: 90210

Current        High           Low
72.4°F         78.1°F         65.2°F
```

A "Cached result" badge is shown when the forecast is served from cache.

---

## Application flow

```text
User enters an address or ZIP code
↓
ForecastLookupService checks the cache
↓
If cached, returns the cached forecast
↓
If not cached, the input is resolved to a location:
  ZIP code → ZipCodeLookupService (Zippopotam.us)
  address  → AddressLookupService (Nominatim)
↓
WeatherForecastService retrieves forecast data
↓
ForecastLookupService stores the result in cache for 30 minutes
↓
The forecast is displayed to the user
```

---

## Service objects

The application uses service objects to keep responsibilities isolated and the controller simple.

### ForecastLookupService

Orchestrates the full forecast lookup flow.

Responsibilities:

- Normalize the input (address or ZIP code)
- Check whether a cached forecast exists
- Route the input to the right resolver: ZipCodeLookupService for ZIP codes, AddressLookupService for addresses
- Call the weather forecast service
- Store the forecast result in cache when the lookup succeeds
- Return the forecast with a `from_cache` indicator

### ZipCodeLookupService

Responsible for converting a US ZIP code into location data.

It validates the ZIP code format, calls Zippopotam.us, and normalizes the response into a predictable structure. Invalid ZIP codes and failed lookups return `nil`.

Example output:

```ruby
{
  zip_code: "90210",
  city: "Beverly Hills",
  state: "California",
  latitude: 34.0901,
  longitude: -118.4065
}
```

### AddressLookupService

Responsible for converting a free-text address into location data.

It geocodes the address through OpenStreetMap's Nominatim API and normalizes the response into the same structure as `ZipCodeLookupService`. Empty input, no results, and failed lookups return `nil`.

Example output:

```ruby
{
  zip_code: "94043",
  city: "Mountain View",
  state: "California",
  latitude: 37.4220,
  longitude: -122.0841
}
```

### WeatherForecastService

Responsible for retrieving weather forecast data using latitude and longitude.

It calls Open-Meteo and normalizes the response.

Example output:

```ruby
{
  current_temperature: 72.4,
  high_temperature: 78.1,
  low_temperature: 65.2
}
```

---

## External APIs

This project uses three public APIs, all key-less.

### Zippopotam.us

Used to convert a US ZIP code into location data, including:

- ZIP code
- City
- State
- Latitude
- Longitude

This API was chosen because it is simple, public, and does not require an API key. It is a community-run service with no formal SLA, so calls are wrapped in timeouts and fail gracefully (see Error handling).

### Nominatim (OpenStreetMap)

Used to geocode free-text addresses into coordinates (and a ZIP code, city, and state when available).

It was chosen because it handles real street addresses, requires no API key, and returns structured address details. Its usage policy (a descriptive `User-Agent` and light request rates) is respected; for higher production volume a dedicated geocoding provider would be more appropriate.

### Open-Meteo

Used to retrieve weather forecast data based on latitude and longitude.

This API was chosen because it supports latitude/longitude queries, provides current and daily forecast data, and does not require an API key. Its free tier is intended for non-commercial use and is rate-limited; a commercial deployment would move to its paid plan or another provider — a one-line change behind `WeatherForecastService`.

---

## Caching strategy

Forecast results are cached by the search query (ZIP code or address) for 30 minutes.

The cache wraps the full lookup flow, including location resolution and weather retrieval. The cache key is the normalized query, so a repeated search — by ZIP code or by address — is served entirely from cache.

When a cached result is available, the application does not call any external API.

The response includes a `from_cache` indicator:

```ruby
{
  zip_code: "90210",
  city: "Beverly Hills",
  state: "California",
  current_temperature: 72.4,
  high_temperature: 78.1,
  low_temperature: 65.2,
  from_cache: false
}
```

This satisfies the requirement:

```text
Cache the forecast details for 30 minutes for all subsequent requests by ZIP code.
```

### Cache store

The cache is reached through an injected store, so the backend can change without touching the service code.

In production, the application uses Redis when the `REDIS_URL` environment variable is set, so the cache is shared across instances. Otherwise it falls back to a per-process store:

```ruby
if ENV["REDIS_URL"].present?
  config.cache_store = :redis_cache_store, { url: ENV["REDIS_URL"] }
else
  config.cache_store = :memory_store
end
```

Solid Cache was skipped because it is backed by Active Record; since this application has no database, a lightweight Redis store is a better fit when a shared cache is needed.

---

## Architectural decisions

This application does not use a database because it does not need to persist users, searches, addresses, or forecast data.

The only temporary data required is the weather forecast cache, which expires after 30 minutes.

For this reason, the following Rails components were intentionally skipped:

- Active Record
- Solid Cache
- Solid Queue
- Solid Cable
- Active Job
- Action Mailer
- Action Mailbox
- Action Text
- Active Storage
- Action Cable
- Kamal
- Thruster

The application follows a simple request-response flow:

```text
Input ZIP code
↓
Retrieve forecast
↓
Cache result
↓
Display result
```

Adding database-backed cache, background jobs, WebSockets, file uploads, or email support would add unnecessary complexity for this challenge.

A detailed record of these and other decisions, with the trade-offs each one accepts, is kept in [docs/DECISIONS.md](docs/DECISIONS.md).

---

## Why two providers instead of the Geocoder gem?

Location resolution is split by input type: Zippopotam.us for ZIP codes and Nominatim for free-text addresses.

The `geocoder` gem was considered as a single abstraction over both. However, its ZIP/postal-code behavior depends on the configured provider and varies by country and data source, which makes it less predictable. Calling the two APIs directly keeps the behavior explicit and lets each input type use the provider best suited to it:

- ZIP codes use Zippopotam.us — a direct, predictable ZIP-to-location lookup.
- Addresses use Nominatim — real street-address geocoding from OpenStreetMap.

Both are public and need no API key. Benefits of calling them directly:

- Explicit, provider-specific behavior instead of a generic abstraction
- No API key required
- Simple JSON responses
- Easier to test (the HTTP client is injected) and explain

---

## Why not use a weather-specific gem?

Weather-specific Ruby gems were also considered.

However, many of them are tied to specific providers, require API keys, are not actively maintained, or add an unnecessary abstraction layer for a small project.

Using Faraday directly keeps the integration:

- Simple
- Explicit
- Easy to test
- Easy to debug
- Independent from gem-specific abstractions

Faraday was chosen specifically for its pluggable adapter layer: the HTTP backend (Net::HTTP, Typhoeus, async, etc.) can be swapped, and cross-cutting concerns such as retries, logging, and instrumentation can be added as middleware — all behind one stable API, without changing the call sites. That shared plumbing lives in the `ExternalApi` mixin.

For this reason, the application uses Faraday to call the external APIs directly.

---

## Why a query parameter instead of a path segment?

The forecast lookup is exposed as `GET /forecast?location=90210` rather than `GET /forecasts/90210`.

A forecast lookup is conceptually a search, not a stored resource, so a query parameter models it more honestly. It also lets the search form work as plain HTML:

```erb
<form method="get" action="/forecast">
```

Because of this, the application works without JavaScript. An earlier version used a path segment, which forced the form to build the URL in JavaScript and broke entirely when scripting was unavailable. The query-parameter form removes that dependency, and Hotwire still enhances navigation when JavaScript is present.

---

## Error handling

The application handles common failure scenarios gracefully, including:

- Empty input
- Addresses or ZIP codes that cannot be resolved
- Failed responses from external APIs
- Invalid JSON responses
- Missing location data
- Missing or incomplete forecast data
- Slow external APIs

External calls go through Faraday with explicit connection (`open_timeout`) and read (`timeout`) limits, so a slow upstream cannot hang a request indefinitely. Timeouts and connection errors raise `Faraday::Error`, which is rescued and surfaces as a normal "could not retrieve" result rather than an exception.

A successful response with missing temperature data is treated as a failure as well, so an incomplete forecast is never displayed or cached.

The user-facing message distinguishes the two cases the user can act on:

- Empty input asks the user to enter an address or US ZIP code.
- An input that cannot be resolved (not found, API failure, timeout) shows a "try again" message.

When a forecast cannot be retrieved, the user sees a friendly error message instead of an application error.

---

## Testing strategy

The application is tested through request specs, view specs, service specs, and contract specs.

### Request specs

- User can access the forecast search page
- A valid ZIP code returns a successful response
- An unresolvable ZIP code returns an unprocessable response

### View specs

- The search page renders a plain HTML GET form (no JavaScript required)
- The search page shows an alert when a flash message is present
- The forecast page renders the location and temperatures
- The cache badge is shown only when the result came from cache

### Service specs

- `ZipCodeLookupService` returns normalized location data
- `ZipCodeLookupService` handles invalid ZIP codes
- `ZipCodeLookupService` handles failed API responses
- `WeatherForecastService` returns normalized forecast data
- `WeatherForecastService` handles failed API responses
- `WeatherForecastService` returns nil when forecast data is incomplete
- `ForecastLookupService` returns cached results when available
- `ForecastLookupService` writes results to cache when no cache exists

Most specs accept the HTTP client and cache store as injected dependencies, so external calls and the cache are replaced with test doubles. This keeps the suite fast, deterministic, and independent from network availability.

### Contract specs

A small set of specs in `spec/contracts/` run the real Faraday client against WebMock-stubbed endpoints. They verify that each integration builds the right request (URL, params, and the Nominatim `User-Agent`) and parses a realistic response — a tripwire for a malformed request or a changed upstream response shape that the dependency-injected unit specs cannot catch.

### Coverage

Code coverage is measured with SimpleCov and enforced in CI through a minimum line-coverage threshold, so a drop in coverage fails the build. The HTML report is uploaded as a CI artifact.

---

## Forecast response shape

The internal forecast response follows this structure:

```ruby
{
  zip_code: "90210",
  city: "Beverly Hills",
  state: "California",
  latitude: 34.0901,
  longitude: -118.4065,
  current_temperature: 72.4,
  high_temperature: 78.1,
  low_temperature: 65.2,
  from_cache: false
}
```

---

## Future improvements

Possible improvements for a production version:

- Support ZIP+4 format
- Add more detailed forecast information
- Add hourly forecast data
- Add better UI styling
- Add rate-limit protection
- Add observability around external API failures
- Add retry logic for temporary API failures
- Add support for other countries or postal code formats

---

## Summary

Forecastly was intentionally designed as a small, focused Rails application.

The main goal was to satisfy the challenge requirements without adding unnecessary infrastructure.

The application:

- Accepts a US address or ZIP code
- Resolves it to a location
- Retrieves weather forecast data
- Caches the forecast by query for 30 minutes
- Displays whether the result came from cache
- Avoids unnecessary database and framework features