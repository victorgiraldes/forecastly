require "rails_helper"

RSpec.describe ForecastLookupService do
  describe ".call" do
    let(:cache) { instance_double("ActiveSupport::Cache::Store") }

    context "when the forecast is cached" do
      let(:query) { "90210" }
      let(:cached_forecast) do
        {
          zip_code: "90210",
          city: "Beverly Hills",
          state: "California",
          latitude: 34.0901,
          longitude: -118.4065,
          current_temperature: 75.0,
          high_temperature: 80.0,
          low_temperature: 60.0
        }
      end

      before do
        allow(cache).to receive(:read).with("forecast:90210").and_return(cached_forecast)
      end

      it "returns the cached forecast with from_cache: true" do
        result = described_class.call(query, cache: cache)

        expect(result).to eq(cached_forecast.merge(from_cache: true))
      end
    end

    context "when a ZIP code is not cached" do
      let(:query) { "90210" }

      before do
        allow(cache).to receive(:read).with("forecast:90210").and_return(nil)
        allow(cache).to receive(:write)
        allow(ZipCodeLookupService).to receive(:call).with(query).and_return(
          zip_code: "90210",
          city: "Beverly Hills",
          state: "California",
          latitude: 34.0901,
          longitude: -118.4065
        )
        allow(WeatherForecastService).to receive(:call).with(latitude: 34.0901, longitude: -118.4065).and_return(
          current_temperature: 75.0,
          high_temperature: 80.0,
          low_temperature: 60.0
        )
      end

      it "resolves via the ZIP service and caches the result" do
        result = described_class.call(query, cache: cache)

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

        expect(cache).to have_received(:write).with(
          "forecast:90210",
          hash_including(zip_code: "90210", city: "Beverly Hills"),
          expires_in: ForecastLookupService::CACHE_EXPIRATION
        )
      end
    end

    context "when the input is an address" do
      let(:query) { "1600 Amphitheatre Parkway, Mountain View, CA" }

      before do
        allow(cache).to receive(:read).and_return(nil)
        allow(cache).to receive(:write)
        allow(ZipCodeLookupService).to receive(:call)
        allow(AddressLookupService).to receive(:call).with(query).and_return(
          zip_code: "94043",
          city: "Mountain View",
          state: "California",
          latitude: 37.4220,
          longitude: -122.0841
        )
        allow(WeatherForecastService).to receive(:call).with(latitude: 37.4220, longitude: -122.0841).and_return(
          current_temperature: 70.0,
          high_temperature: 75.0,
          low_temperature: 55.0
        )
      end

      it "resolves via the address service, not the ZIP service" do
        result = described_class.call(query, cache: cache)

        expect(result).to include(zip_code: "94043", city: "Mountain View", from_cache: false)
        expect(ZipCodeLookupService).not_to have_received(:call)
      end
    end

    context "when the location cannot be resolved" do
      let(:query) { "nowhere at all" }

      before do
        allow(cache).to receive(:read).and_return(nil)
        allow(AddressLookupService).to receive(:call).with(query).and_return(nil)
      end

      it "returns nil" do
        expect(described_class.call(query, cache: cache)).to be_nil
      end
    end

    context "when the query is blank" do
      it "returns nil" do
        expect(described_class.call("   ", cache: cache)).to be_nil
      end
    end
  end
end
