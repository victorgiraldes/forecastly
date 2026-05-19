require 'rails_helper'

RSpec.describe "Forecasts", type: :request do
  describe "GET /forecasts/new" do
    it "returns http success" do
      get "/forecasts/new"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /forecasts/:zip_code" do
    let(:zip_code) { "90210" }
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
        allow(ForecastLookupService).to receive(:call).with(zip_code).and_return(forecast)
      end

      it "returns http success" do
        get "/forecasts/#{zip_code}"
        expect(response).to have_http_status(:success)
      end
    end

    context "when the forecast is not found" do
      before do
        allow(ForecastLookupService).to receive(:call).with(zip_code).and_return(nil)
      end

      it "returns unprocessable entity" do
        get "/forecasts/#{zip_code}"
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end
