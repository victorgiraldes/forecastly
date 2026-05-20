require 'rails_helper'

RSpec.describe "Forecasts", type: :request do
  describe "GET /forecasts/new" do
    it "returns http success" do
      get "/forecasts/new"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /forecast" do
    let(:location) { "90210" }
    let(:forecast) do
      {
        zip_code: "90210",
        city: "Beverly Hills",
        state: "California",
        latitude: 34.0901,
        longitude: -118.4065,
        current_temperature: 75.0,
        high_temperature: 80.0,
        low_temperature: 65.0
      }
    end

    context "when the forecast is found" do
      before do
        allow(ForecastLookupService).to receive(:call).with(location).and_return(forecast)
      end

      it "returns http success" do
        get "/forecast", params: { location: location }
        expect(response).to have_http_status(:success)
      end
    end

    context "when the forecast is not found" do
      before do
        allow(ForecastLookupService).to receive(:call).with(location).and_return(nil)
      end

      it "returns unprocessable entity" do
        get "/forecast", params: { location: location }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "when no location is provided" do
      it "asks the user for an address or ZIP code" do
        get "/forecast", params: { location: "" }

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("address or US ZIP code")
      end
    end
  end
end
