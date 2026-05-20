require 'rails_helper'

RSpec.describe "forecasts/new.html.erb", type: :view do
  it "renders a GET search form pointing at the forecast path" do
    render

    expect(rendered).to include('method="get"')
    expect(rendered).to include("action=\"#{forecast_path}\"")
    expect(rendered).to include('name="location"')
    expect(rendered).to include("required")
  end

  it "shows an alert when one is present" do
    allow(view).to receive(:flash).and_return({ alert: "Please enter an address or US ZIP code." })

    render

    expect(rendered).to include("Please enter an address or US ZIP code.")
  end
end
