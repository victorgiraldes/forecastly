class ForecastLookupService
  CACHE_EXPIRATION = 30.minutes

  def self.call(zip_code, cache: Rails.cache)
    new(zip_code, cache: cache).call
  end

  def initialize(zip_code, cache: Rails.cache)
    @zip_code = zip_code.to_s.strip
    @cache = cache
  end

  def call
    cached_forecast = @cache.read(cache_key)

    if cached_forecast.present?
      return cached_forecast.merge(from_cache: true)
    end

    location = ZipCodeLookupService.call(@zip_code)
    return unless location

    forecast = WeatherForecastService.call(
      latitude: location[:latitude],
      longitude: location[:longitude]
    )
    return unless forecast

    result = build_result(location, forecast)

    @cache.write(cache_key, result, expires_in: CACHE_EXPIRATION)

    result.merge(from_cache: false)
  end

  private

  def cache_key
    "forecast:zip_code:#{@zip_code}"
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