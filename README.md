# Forecastly

Forecastly is a minimal Rails application that retrieves weather forecast data for a given US ZIP code.

The application allows users to enter a ZIP code, retrieves location data, fetches the weather forecast, caches the result for 30 minutes, and indicates whether the response came from cache.

---

## Features

- Search weather forecast by US ZIP code
- Retrieve location data from Zippopotam.us
- Retrieve weather forecast data from Open-Meteo
- Display current temperature
- Display daily high and low temperatures
- Cache forecast results by ZIP code for 30 minutes
- Indicate whether the result came from cache
- Handle invalid ZIP codes and external API failures gracefully

---

## Requirements

- Ruby 3.x
- Rails 7.x or 8.x
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

Enter a valid US ZIP code, for example:

```text
90210
10001
33101
```

The application will display the forecast for the corresponding location.

Example result:

```text
Location: Beverly Hills, California
Current temperature: 72.4°F
High: 78.1°F
Low: 65.2°F
From cache: No
```

---

## Application flow

```text
User enters a ZIP code
↓
ForecastLookupService checks the cache
↓
If cached, returns the cached forecast
↓
If not cached, ZipCodeLookupService retrieves location data
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

- Normalize the ZIP code
- Validate the ZIP code format
- Check whether a cached forecast exists
- Call the ZIP code lookup service
- Call the weather forecast service
- Store the forecast result in cache
- Return the forecast with a `from_cache` indicator

### ZipCodeLookupService

Responsible for converting a US ZIP code into location data.

It calls Zippopotam.us and normalizes the response into a predictable structure.

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

This project uses two public APIs.

### Zippopotam.us

Used to convert a US ZIP code into location data, including:

- ZIP code
- City
- State
- Latitude
- Longitude

This API was chosen because it is simple, public, and does not require an API key.

### Open-Meteo

Used to retrieve weather forecast data based on latitude and longitude.

This API was chosen because it supports latitude/longitude queries, provides current and daily forecast data, and does not require an API key.

---

## Caching strategy

Forecast results are cached by ZIP code for 30 minutes.

The cache wraps the full lookup flow, including ZIP code resolution and weather retrieval.

When a cached result is available, the application does not call the external ZIP code or weather APIs.

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

---

## Why not use the Geocoder gem?

The `geocoder` gem was considered for converting ZIP codes into latitude and longitude.

However, ZIP code and postal code support depends on the provider configured behind the gem. Support can vary depending on the country, data source, and provider behavior.

During the planning phase, there was also a concern about CEP-style postal code support. Since this challenge focuses on US ZIP codes, using a direct ZIP-code lookup API was more predictable.

For that reason, Zippopotam.us was chosen instead of a generic geocoding abstraction.

Benefits of this decision:

- Direct ZIP-code-to-location lookup
- No API key required
- Simple JSON response
- Easier to test and explain
- Less provider-dependent behavior

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

For this reason, the application uses Faraday to call Open-Meteo directly.

---

## Error handling

The application handles common failure scenarios gracefully, including:

- Invalid ZIP code format
- ZIP codes not found by the location API
- Failed responses from external APIs
- Invalid JSON responses
- Missing location data
- Missing forecast data

When a forecast cannot be retrieved, the user sees a friendly error message instead of an application error.

---

## Testing strategy

The application can be tested through request specs and service specs.

Recommended test coverage:

### Request specs

- User can access the forecast search page
- User can search for a valid ZIP code
- User sees the forecast result
- User sees a cache indicator
- User sees an error message for invalid ZIP codes

### Service specs

- `ZipCodeLookupService` returns normalized location data
- `ZipCodeLookupService` handles invalid ZIP codes
- `ZipCodeLookupService` handles failed API responses
- `WeatherForecastService` returns normalized forecast data
- `WeatherForecastService` handles failed API responses
- `ForecastLookupService` returns cached results when available
- `ForecastLookupService` writes results to cache when no cache exists

External API calls should be stubbed or mocked in tests to keep the test suite fast, deterministic, and independent from network availability.

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

- Support full address search
- Support ZIP+4 format
- Add more detailed forecast information
- Add hourly forecast data
- Add better UI styling
- Add rate-limit protection
- Add observability around external API failures
- Add retry logic for temporary API failures
- Add persistent cache for multi-instance production environments
- Add support for other countries or postal code formats

---

## Summary

Forecastly was intentionally designed as a small, focused Rails application.

The main goal was to satisfy the challenge requirements without adding unnecessary infrastructure.

The application:

- Accepts a US ZIP code
- Retrieves location data
- Retrieves weather forecast data
- Caches the forecast by ZIP code for 30 minutes
- Displays whether the result came from cache
- Avoids unnecessary database and framework features