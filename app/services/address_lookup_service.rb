class AddressLookupService
  include ExternalApi

  BASE_URL = "https://nominatim.openstreetmap.org/search".freeze
  USER_AGENT = "Forecastly/1.0 (Rails weather take-home)".freeze

  def self.call(address, client: Faraday)
    new(address, client: client).call
  end

  def initialize(address, client: Faraday)
    @address = address.to_s.strip
    @client = client
  end

  def call
    return if @address.empty?

    response = http_get(BASE_URL, params) do |req|
      req.headers["User-Agent"] = USER_AGENT
    end
    return unless response&.success?

    body = parse_response(response)
    return unless body.is_a?(Array)

    place = body.first
    return unless place

    normalize_data(place)
  end

  private

  def params
    {
      q: @address,
      format: "jsonv2",
      addressdetails: 1,
      limit: 1
    }
  end

  def normalize_data(place)
    address = place["address"] || {}

    {
      zip_code: address["postcode"],
      city: address["city"] || address["town"] || address["village"] || address["county"],
      state: address["state"],
      latitude: place["lat"].to_f,
      longitude: place["lon"].to_f
    }
  end
end
