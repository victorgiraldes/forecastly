class ForecastsController < ApplicationController
  def new
  end

  def show
    @zip_code = permitted_params[:zip_code]
    @forecast = ForecastLookupService.call(@zip_code)

    return if @forecast.present?

    flash.now[:alert] = "Could not find forecast for this ZIP code."
    render :new, status: :unprocessable_content
  end

  private

  def permitted_params
    params.permit(:zip_code)
  end
end
