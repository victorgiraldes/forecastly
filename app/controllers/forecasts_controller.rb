class ForecastsController < ApplicationController
  def new
  end

  def show
    @location = permitted_params[:location]
    @forecast = ForecastLookupService.call(@location)

    return if @forecast.present?

    flash.now[:alert] = error_message
    render :new, status: :unprocessable_content
  end

  private

  def error_message
    if @location.blank?
      "Please enter an address or US ZIP code."
    else
      "We couldn't find a forecast for that location. Please try again."
    end
  end

  def permitted_params
    params.permit(:location)
  end
end
