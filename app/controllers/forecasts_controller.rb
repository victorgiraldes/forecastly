class ForecastsController < ApplicationController
  def new
  end

  def show
    @zip_code = permitted_params[:zip_code]
    @forecast = ForecastLookupService.call(@zip_code)

    return if @forecast.present?

    flash.now[:alert] = error_message
    render :new, status: :unprocessable_content
  end

  private

  def error_message
    if ZipCodeLookupService.valid_format?(@zip_code)
      "We couldn't retrieve the forecast right now. Please try again."
    else
      "Please enter a valid 5-digit US ZIP code."
    end
  end

  def permitted_params
    params.permit(:zip_code)
  end
end
