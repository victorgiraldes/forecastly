class ForecastLookupService
  CACHE_EXPIRATION = 30.minutes

  def self.call(query, cache: Rails.cache)
    new(query, cache: cache).call
  end

  def initialize(query, cache: Rails.cache)
    @query = query.to_s.strip
    @cache = cache
  end

  def call
    return if @query.empty?

    cached_forecast = @cache.read(cache_key)

    if cached_forecast.present?
      return cached_forecast.merge(from_cache: true)
    end

    location = resolve_location
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

  def resolve_location
    return ZipCodeLookupService.call(@query) if ZipCodeLookupService.valid_format?(@query)

    AddressLookupService.call(@query)
  end

  def cache_key
    "forecast:#{@query.downcase}"
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
