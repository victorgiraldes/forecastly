class ZipCodeLookupService
  BASE_URL = "https://api.zippopotam.us/us/".freeze

  def self.call(zip_code, client: Faraday)
    new(zip_code, client: client).call
  end

  def initialize(zip_code, client:)
    @zip_code = normalize_zip_code(zip_code)
    @client = client
  end

  def call
    return unless valid_zip_code?(@zip_code)

    response = @client.get("#{BASE_URL}#{@zip_code}")

    return unless response.success?

    body = parse_response(response)
    return unless body

    place = body["places"]&.first
    return unless place

    normalize_data(body, place)
  rescue Faraday::Error => e
    Rails.logger.error("ZipCodeLookupService error: #{e.message}")
    nil
  end

  private

  def normalize_zip_code(zip_code)
    zip_code.to_s.strip
  end

  def valid_zip_code?(zip_code)
    zip_code.match?(/\A\d{5}\z/)
  end

  def parse_response(response)
    JSON.parse(response.body)
  rescue JSON::ParserError
    nil
  end

  def normalize_data(data, place)
    {
      zip_code: data["post code"],
      city: place["place name"],
      state: place["state"],
      latitude: place["latitude"].to_f,
      longitude: place["longitude"].to_f
    }
  end
end