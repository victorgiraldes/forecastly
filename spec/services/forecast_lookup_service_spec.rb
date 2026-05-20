require "rails_helper"

RSpec.describe ForecastLookupService do
  describe ".call" do
    # A real in-memory store keeps the two-tier caching behaviour honest.
    let(:cache) { ActiveSupport::Cache::MemoryStore.new }

    let(:beverly_hills) do
      {
        zip_code: "90210",
        city: "Beverly Hills",
        state: "California",
        latitude: 34.0901,
        longitude: -118.4065
      }
    end

    let(:weather) do
      {
        current_temperature: 75.0,
        high_temperature: 80.0,
        low_temperature: 60.0
      }
    end

    context "with a ZIP query" do
      before do
        allow(ZipCodeLookupService).to receive(:call).with("90210").and_return(beverly_hills)
        allow(WeatherForecastService).to receive(:call)
          .with(latitude: 34.0901, longitude: -118.4065).and_return(weather)
      end

      it "returns the full forecast with from_cache: false on a miss" do
        result = described_class.call("90210", cache: cache)

        expect(result).to eq(
          zip_code: "90210",
          city: "Beverly Hills",
          state: "California",
          latitude: 34.0901,
          longitude: -118.4065,
          current_temperature: 75.0,
          high_temperature: 80.0,
          low_temperature: 60.0,
          from_cache: false
        )
      end

      it "serves a cache hit on the second call without re-calling the APIs" do
        described_class.call("90210", cache: cache)
        result = described_class.call("90210", cache: cache)

        expect(result[:from_cache]).to be(true)
        expect(ZipCodeLookupService).to have_received(:call).once
        expect(WeatherForecastService).to have_received(:call).once
      end
    end

    context "with an address query" do
      before do
        allow(ZipCodeLookupService).to receive(:call)
        allow(AddressLookupService).to receive(:call)
          .with("1600 Amphitheatre Parkway").and_return(beverly_hills.merge(city: "Mountain View"))
        allow(WeatherForecastService).to receive(:call).and_return(weather)
      end

      it "resolves via the address service, not the ZIP service" do
        result = described_class.call("1600 Amphitheatre Parkway", cache: cache)

        expect(result).to include(city: "Mountain View", from_cache: false)
        expect(ZipCodeLookupService).not_to have_received(:call)
      end
    end

    context "when two address spellings resolve to the same ZIP" do
      before do
        allow(AddressLookupService).to receive(:call)
          .with("1600 Amphitheatre Pkwy")
          .and_return(zip_code: "94043", city: "Mountain View", state: "California", latitude: 37.4220, longitude: -122.0841)
        allow(AddressLookupService).to receive(:call)
          .with("1600 Amphitheatre Parkway, Mountain View")
          .and_return(zip_code: "94043", city: "Mountain View", state: "California", latitude: 37.4221, longitude: -122.0842)
        allow(WeatherForecastService).to receive(:call).and_return(weather)
      end

      it "shares the forecast cache by ZIP, fetching weather only once" do
        described_class.call("1600 Amphitheatre Pkwy", cache: cache)
        result = described_class.call("1600 Amphitheatre Parkway, Mountain View", cache: cache)

        expect(result[:from_cache]).to be(true)
        expect(WeatherForecastService).to have_received(:call).once
      end
    end

    context "when the resolved location has no ZIP code" do
      before do
        allow(AddressLookupService).to receive(:call)
          .with("remote place")
          .and_return(zip_code: nil, city: "Remote", state: "Nowhere", latitude: 12.345678, longitude: 98.765432)
        allow(WeatherForecastService).to receive(:call).and_return(weather)
      end

      it "still returns a forecast (cached by coordinates)" do
        result = described_class.call("remote place", cache: cache)

        expect(result).to include(zip_code: nil, city: "Remote", from_cache: false)
      end
    end

    context "when the location cannot be resolved" do
      before do
        allow(AddressLookupService).to receive(:call).with("nowhere at all").and_return(nil)
      end

      it "returns nil" do
        expect(described_class.call("nowhere at all", cache: cache)).to be_nil
      end
    end

    context "when the query is blank" do
      it "returns nil" do
        expect(described_class.call("   ", cache: cache)).to be_nil
      end
    end
  end
end
