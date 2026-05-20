class ZipCodeLookupService
  include ExternalApi

  BASE_URL = "https://api.zippopotam.us/us/".freeze
  ZIP_CODE_FORMAT = /\A\d{5}\z/

  def self.call(zip_code, client: Faraday)
    new(zip_code, client: client).call
  end

  def self.valid_format?(zip_code)
    zip_code.to_s.strip.match?(ZIP_CODE_FORMAT)
  end

  def initialize(zip_code, client:)
    @zip_code = normalize_zip_code(zip_code)
    @client = client
  end

  def call
    return unless valid_zip_code?(@zip_code)

    response = http_get("#{BASE_URL}#{@zip_code}")
    return unless response&.success?

    body = parse_response(response)
    return unless body

    place = body["places"]&.first
    return unless place

    normalize_data(body, place)
  end

  private

  def normalize_zip_code(zip_code)
    zip_code.to_s.strip
  end

  def valid_zip_code?(zip_code)
    zip_code.match?(ZIP_CODE_FORMAT)
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
