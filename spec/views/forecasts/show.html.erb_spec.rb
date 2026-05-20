require 'rails_helper'

RSpec.describe "forecasts/show.html.erb", type: :view do
  let(:forecast) do
    {
      zip_code: "90210",
      city: "Beverly Hills",
      state: "California",
      current_temperature: 72.4,
      high_temperature: 78.1,
      low_temperature: 65.2,
      from_cache: false
    }
  end

  it "shows the location and temperatures" do
    assign(:forecast, forecast)

    render

    expect(rendered).to include("Beverly Hills")
    expect(rendered).to include("California")
    expect(rendered).to include("90210")
    expect(rendered).to include("72.4")
    expect(rendered).to include("78.1")
    expect(rendered).to include("65.2")
  end

  it "shows the cache badge when the result came from cache" do
    assign(:forecast, forecast.merge(from_cache: true))

    render

    expect(rendered).to include("Cached result")
  end

  it "does not show the cache badge for a fresh result" do
    assign(:forecast, forecast.merge(from_cache: false))

    render

    expect(rendered).not_to include("Cached result")
  end

  it "omits the ZIP line and joins gracefully when the address has no ZIP code" do
    assign(:forecast, forecast.merge(zip_code: nil, state: nil))

    render

    expect(rendered).not_to include("ZIP Code:")
    expect(rendered).to include("Beverly Hills")
    expect(rendered).not_to include("Beverly Hills,")
  end
end
