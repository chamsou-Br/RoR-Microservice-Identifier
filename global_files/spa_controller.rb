# frozen_string_literal: true

#
# Loads the SPA.  Its sub-modules are loaded dynamically by the front-end
#
class SpaController < ApplicationController
  layout "react"

  before_action :check_improver_access
  before_action :check_risk_access

  #
  # Sends 403 'Unauthorized' header on Pundit policy authorization failure.
  #
  def user_not_authorized
    head :forbidden
  end

  #
  # Default and only action `index` only exists as a placeholder to load view
  #
  def index; end

  private

  #
  # Do not allow accessing improver when it is not enabled
  #
  def check_improver_access
    return unless request.path.include?("improver")
    return if current_customer.access_improver?

    respond_unauthorized
  end

  #
  # Do not allow accessing risk when it is not enabled
  #
  def check_risk_access
    return unless request.path.include?("risks")
    return if current_customer.risk_module?

    respond_unauthorized
  end

  #
  # Respond to the client with a forbidden error
  #
  def respond_unauthorized
    respond_to do |format|
      format.json { render json: {}, status: :forbidden }
      format.html do
        redirect_to root_path, flash: { error: I18n.t("controllers.application.not_authorized") }
      end
    end
  end
end
