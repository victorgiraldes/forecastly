require "rails_helper"

# Contract specs exercise the real HTTP path (Faraday + request building + JSON
# parsing + normalization) against canned responses. Unlike the service unit
# specs, they do NOT inject a fake client — they run the default Faraday client
# and stub the wire with WebMock. They act as a tripwire for a broken request
# (wrong URL, params, or headers) or a changed upstream response shape.

RSpec.describe "External API contracts" do
  describe ZipCodeLookupService do
    it "builds the request and parses a Zippopotam response" do
      stub_request(:get, "https://api.zippopotam.us/us/90210")
        .to_return(
          status: 200,
          headers: { "Content-Type" => "application/json" },
          body: {
            "post code" => "90210",
            "country" => "United States",
            "places" => [
              {
                "place name" => "Beverly Hills",
                "state" => "California",
                "latitude" => "34.0901",
                "longitude" => "-118.4065"
              }
            ]
          }.to_json
        )

      result = described_class.call("90210")

      expect(result).to eq(
        zip_code: "90210",
        city: "Beverly Hills",
        state: "California",
        latitude: 34.0901,
        longitude: -118.4065
      )
    end
  end

  describe AddressLookupService do
    let(:address) { "1600 Amphitheatre Parkway, Mountain View, CA" }

    it "sends the User-Agent and parses a Nominatim response" do
      stub_request(:get, "https://nominatim.openstreetmap.org/search")
        .with(
          query: hash_including("q" => address, "format" => "jsonv2"),
          headers: { "User-Agent" => "Forecastly/1.0 (Rails weather take-home)" }
        )
        .to_return(
          status: 200,
          headers: { "Content-Type" => "application/json" },
          body: [
            {
              "lat" => "37.4220",
              "lon" => "-122.0841",
              "address" => {
                "city" => "Mountain View",
                "state" => "California",
                "postcode" => "94043"
              }
            }
          ].to_json
        )

      result = described_class.call(address)

      expect(result).to eq(
        zip_code: "94043",
        city: "Mountain View",
        state: "California",
        latitude: 37.4220,
        longitude: -122.0841
      )
    end
  end

  describe WeatherForecastService do
    it "requests Fahrenheit current/daily data and parses the response" do
      stub_request(:get, "https://api.open-meteo.com/v1/forecast")
        .with(query: hash_including(
          "latitude" => "34.0901",
          "longitude" => "-118.4065",
          "current" => "temperature_2m",
          "daily" => "temperature_2m_max,temperature_2m_min",
          "temperature_unit" => "fahrenheit"
        ))
        .to_return(
          status: 200,
          headers: { "Content-Type" => "application/json" },
          body: {
            "current" => { "temperature_2m" => 72.4 },
            "daily" => {
              "temperature_2m_max" => [ 78.1 ],
              "temperature_2m_min" => [ 65.2 ]
            }
          }.to_json
        )

      result = described_class.call(latitude: 34.0901, longitude: -118.4065)

      expect(result).to eq(
        current_temperature: 72.4,
        high_temperature: 78.1,
        low_temperature: 65.2
      )
    end
  end
end
