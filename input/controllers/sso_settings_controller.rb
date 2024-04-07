# frozen_string_literal: true

class SsoSettingsController < ApplicationController
  before_action :check_policies

  def edit
    @sso_settings = current_customer.settings.sso_settings || current_customer.settings.build_sso_settings
  end

  def update
    @sso_settings = current_customer.settings.sso_settings || current_customer.settings.build_sso_settings

    if @sso_settings.update(sso_settings_params)
      flash[:success] = "Success"
      redirect_to edit_sso_settings_path
    else
      flash[:error] = "Fail to update"
      render :edit
    end
  end

  private

  def sso_settings_params
    # Disabling this cop because `cert_x509` is an appropriate name and is the
    # related DB column name
    # rubocop:disable Naming/VariableNumber
    params.require(:customer_sso_setting).permit(:sso_url, :slo_url, :cert_x509, :idp_name,
                                                 :email_key, :firstname_key, :lastname_key,
                                                 :function_key, :service_key, :phone_key, :mobile_phone_key,
                                                 :groups_key, :roles_key)
    # rubocop:enable Naming/VariableNumber
  end

  def check_policies
    @settings = current_customer.settings

    authorize @settings, :sso_settings?
  end
end
