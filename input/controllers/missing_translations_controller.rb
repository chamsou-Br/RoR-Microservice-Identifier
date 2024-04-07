# frozen_string_literal: true

# Handles missing translation HTTP requests from the frontend
class MissingTranslationsController < ApplicationController
  # Creates a notification for a missing translation discovered by the frontend
  def create
    I18n::MissingKeyLogger.log_the(message)

    head :created
  end

  private

  # Returns a log message containing various missing translation metadata
  #
  # @return [String]
  def message
    "#{missing_params[:message]}, url: #{missing_params[:url]}"
  end

  # Sanitizes and returns safe HTTP params
  #
  # @return [ActionController::Parameters]
  def missing_params
    params.permit(:key, :locale, :message, :url)
  end
end
