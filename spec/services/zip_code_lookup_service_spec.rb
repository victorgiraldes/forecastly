require "rails_helper"

RSpec.describe ZipCodeLookupService do
  describe ".call" do
    let(:zip_code) { "90210" }
    let(:client) { class_double("Faraday") }
    let(:response) { instance_double("Faraday::Response") }

    before do
      allow(client).to receive(:get).and_return(response)
    end

    context "when the zip code is valid and the API returns a successful response" do
      let(:response_body) do
        {
          "post code" => "90210",
          "country" => "United States",
          "country abbreviation" => "US",
          "places" => [
            {
              "place name" => "Beverly Hills",
              "longitude" => "-118.4065",
              "state" => "California",
              "state abbreviation" => "CA",
              "latitude" => "34.0901"
            }
          ]
        }.to_json
      end

      before do
        allow(response).to receive(:success?).and_return(true)
        allow(response).to receive(:body).and_return(response_body)
      end

      it "returns normalized location data" do
        result = described_class.call(zip_code, client: client)

        expect(result).to eq(
          zip_code: "90210",
          city: "Beverly Hills",
          state: "California",
          latitude: 34.0901,
          longitude: -118.4065
        )
      end
    end

    context "when the zip code is invalid" do
      let(:zip_code) { "invalid_zip" }

      it "returns nil" do
        result = described_class.call(zip_code, client: client)

        expect(result).to be_nil
      end
    end

    context "when the API returns an unsuccessful response" do
      before do
        allow(response).to receive(:success?).and_return(false)
      end

      it "returns nil" do
        result = described_class.call(zip_code, client: client)

        expect(result).to be_nil
      end
    end

    context "when the API response is malformed" do
      before do
        allow(response).to receive(:success?).and_return(true)
        allow(response).to receive(:body).and_return("invalid_json")
      end

      it "returns nil" do
        result = described_class.call(zip_code, client: client)

        expect(result).to be_nil
      end
    end
  end
end