class ForecastLookupService
  CACHE_EXPIRATION = 30.minutes
  LOCATION_CACHE_EXPIRATION = 1.day

  def self.call(query, cache: Rails.cache)
    new(query, cache: cache).call
  end

  def initialize(query, cache: Rails.cache)
    @query = query.to_s.strip
    @cache = cache
  end

  def call
    return if @query.empty?

    location = resolve_location
    return unless location

    forecast, from_cache = fetch_forecast(location)
    return unless forecast

    build_result(location, forecast).merge(from_cache: from_cache)
  end

  private

  def resolve_location
    cached = @cache.read(location_key)
    return cached if cached.present?

    location = lookup_location
    return unless location

    @cache.write(location_key, location, expires_in: LOCATION_CACHE_EXPIRATION)
    location
  end

  def lookup_location
    return ZipCodeLookupService.call(@query) if zip_code?(@query)

    AddressLookupService.call(@query)
  end

  def fetch_forecast(location)
    key = forecast_key(location)
    cached = @cache.read(key)
    return [ cached, true ] if cached.present?

    forecast = WeatherForecastService.call(
      latitude: location[:latitude],
      longitude: location[:longitude]
    )
    return [ nil, false ] unless forecast

    @cache.write(key, forecast, expires_in: CACHE_EXPIRATION)
    [ forecast, false ]
  end

  def location_key
    "location:#{@query.downcase}"
  end

  def forecast_key(location)
    zip_code = location[:zip_code].presence
    return "forecast:zip_code:#{zip_code}" if zip_code

    "forecast:geo:#{location[:latitude].round(3)},#{location[:longitude].round(3)}"
  end

  def zip_code?(query)
    ZipCodeLookupService.valid_format?(query)
  end

  def build_result(location, forecast)
    {
      zip_code: location[:zip_code],
      city: location[:city],
      state: location[:state],
      latitude: location[:latitude],
      longitude: location[:longitude],
      current_temperature: forecast[:current_temperature],
      high_temperature: forecast[:high_temperature],
      low_temperature: forecast[:low_temperature]
    }
  end
end
