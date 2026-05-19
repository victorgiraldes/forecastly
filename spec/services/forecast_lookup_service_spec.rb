require "rails_helper"

RSpec.describe ForecastLookupService do
  describe ".call" do
    let(:zip_code) { "90210" }
    let(:cache) { instance_double("ActiveSupport::Cache::Store") }

    context "when the forecast is cached" do
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
        allow(cache).to receive(:read).with("forecast:zip_code:#{zip_code}").and_return(cached_forecast)
      end

      it "returns the cached forecast with from_cache: true" do
        result = described_class.call(zip_code, cache: cache)

        expect(result).to eq(cached_forecast.merge(from_cache: true))
      end
    end

    context "when the forecast is not cached" do
      before do
        allow(cache).to receive(:read).with("forecast:zip_code:#{zip_code}").and_return(nil)
        allow(ZipCodeLookupService).to receive(:call).with(zip_code).and_return(
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
        allow(cache).to receive(:write).with(
          "forecast:zip_code:#{zip_code}",
          hash_including(zip_code: "90210", city: "Beverly Hills", state: "California"),
          expires_in: ForecastLookupService::CACHE_EXPIRATION
        )
      end

      it "returns the forecast with from_cache: false and caches the result" do
        result = described_class.call(zip_code, cache: cache)

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
    end

    context "when the zip code is invalid" do
      let(:zip_code) { "invalid_zip" }

      before do
        allow(cache).to receive(:read).with("forecast:zip_code:#{zip_code}").and_return(nil)
        allow(ZipCodeLookupService).to receive(:call).with(zip_code).and_return(nil)
      end

      it "returns nil" do
        result = described_class.call(zip_code, cache: cache)

        expect(result).to be_nil
      end
    end
  end
end
