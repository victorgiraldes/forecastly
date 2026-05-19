require "rails_helper"

RSpec.describe AddressLookupService do
  describe ".call" do
    let(:address) { "1600 Amphitheatre Parkway, Mountain View, CA" }
    let(:client) { class_double("Faraday") }
    let(:response) { instance_double("Faraday::Response") }

    before do
      allow(client).to receive(:get).and_return(response)
    end

    context "when the address is found" do
      let(:response_body) do
        [
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
      end

      before do
        allow(response).to receive(:success?).and_return(true)
        allow(response).to receive(:body).and_return(response_body)
      end

      it "returns normalized location data" do
        result = described_class.call(address, client: client)

        expect(result).to eq(
          zip_code: "94043",
          city: "Mountain View",
          state: "California",
          latitude: 37.4220,
          longitude: -122.0841
        )
      end
    end

    context "when the address is blank" do
      it "returns nil without calling the API" do
        expect(described_class.call("  ", client: client)).to be_nil
        expect(client).not_to have_received(:get)
      end
    end

    context "when no results are found" do
      before do
        allow(response).to receive(:success?).and_return(true)
        allow(response).to receive(:body).and_return("[]")
      end

      it "returns nil" do
        expect(described_class.call(address, client: client)).to be_nil
      end
    end

    context "when the API returns an unsuccessful response" do
      before do
        allow(response).to receive(:success?).and_return(false)
      end

      it "returns nil" do
        expect(described_class.call(address, client: client)).to be_nil
      end
    end

    context "when the API response is malformed" do
      before do
        allow(response).to receive(:success?).and_return(true)
        allow(response).to receive(:body).and_return("not json")
      end

      it "returns nil" do
        expect(described_class.call(address, client: client)).to be_nil
      end
    end

    context "when the request raises a Faraday error" do
      before do
        allow(client).to receive(:get).and_raise(Faraday::ConnectionFailed, "connection failed")
      end

      it "returns nil" do
        expect(described_class.call(address, client: client)).to be_nil
      end
    end
  end
end
