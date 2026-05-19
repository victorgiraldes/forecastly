class WeatherForecastService
  BASE_URL = "https://api.open-meteo.com/v1/forecast".freeze

  def self.call(latitude:, longitude:, client: Faraday)
    new(latitude, longitude, client: client).call
  end

  def initialize(latitude, longitude, client: Faraday)
    @latitude = latitude
    @longitude = longitude
    @client = client
  end

  def call
    response = @client.get(BASE_URL, params)

    return unless response.success?

    data = parse_response(response)
    return unless data

    normalize_data(data)
  rescue Faraday::Error => e
    Rails.logger.error("WeatherForecastService error: #{e.message}")
    nil
  end

  private

  def params
    {
      latitude: @latitude,
      longitude: @longitude,
      current: "temperature_2m",
      daily: "temperature_2m_max,temperature_2m_min",
      temperature_unit: "fahrenheit",
      timezone: "auto"
    }
  end

  def parse_response(response)
    JSON.parse(response.body)
  rescue JSON::ParserError
    nil
  end

  def normalize_data(data)
    current = data.dig("current", "temperature_2m")
    high = data.dig("daily", "temperature_2m_max")&.first
    low = data.dig("daily", "temperature_2m_min")&.first

    return if current.nil? || high.nil? || low.nil?

    {
      current_temperature: current,
      high_temperature: high,
      low_temperature: low
    }
  end
end
