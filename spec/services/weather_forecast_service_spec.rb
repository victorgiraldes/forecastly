require "rails_helper"

RSpec.describe WeatherForecastService do
  describe ".call" do
    let(:latitude) { 34.0522 }
    let(:longitude) { -118.2437 }
    let(:client) { class_double("Faraday") }
    let(:response) { instance_double("Faraday::Response") }

    before do
      allow(client).to receive(:get).and_return(response)
    end

    context "when the API returns a successful response" do
      let(:response_body) do
        {
          "current" => {
            "temperature_2m" => 75.0
          },
          "daily" => {
            "temperature_2m_max" => [ 80.0 ],
            "temperature_2m_min" => [ 60.0 ]
          }
        }.to_json
      end

      before do
        allow(response).to receive(:success?).and_return(true)
        allow(response).to receive(:body).and_return(response_body)
      end

      it "returns normalized weather data" do
        result = described_class.call(latitude: latitude, longitude: longitude, client: client)

        expect(result).to eq(
          current_temperature: 75.0,
          high_temperature: 80.0,
          low_temperature: 60.0
        )
      end
    end

    context "when the API returns an unsuccessful response" do
      before do
        allow(response).to receive(:success?).and_return(false)
      end

      it "returns nil" do
        result = described_class.call(latitude: latitude, longitude: longitude, client: client)

        expect(result).to be_nil
      end
    end

    context "when the API response is invalid JSON" do
      before do
        allow(response).to receive(:success?).and_return(true)
        allow(response).to receive(:body).and_return("invalid_json")
      end

      it "returns nil" do
        result = described_class.call(latitude: latitude, longitude: longitude, client: client)

        expect(result).to be_nil
      end
    end

    context "when the response is successful but missing temperature data" do
      let(:response_body) do
        {
          "current" => {},
          "daily" => {}
        }.to_json
      end

      before do
        allow(response).to receive(:success?).and_return(true)
        allow(response).to receive(:body).and_return(response_body)
      end

      it "returns nil" do
        result = described_class.call(latitude: latitude, longitude: longitude, client: client)

        expect(result).to be_nil
      end
    end

    context "when the request raises a Faraday error" do
      before do
        allow(client).to receive(:get).and_raise(Faraday::ConnectionFailed, "connection failed")
      end

      it "returns nil" do
        result = described_class.call(latitude: latitude, longitude: longitude, client: client)

        expect(result).to be_nil
      end
    end
  end
end
