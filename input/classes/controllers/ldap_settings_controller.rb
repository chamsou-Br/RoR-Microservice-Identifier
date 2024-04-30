# frozen_string_literal: true

class LdapSettingsController < ApplicationController
  before_action :check_policies
  before_action :load_ldap_settings, only: %i[edit update activate destroy]

  def index
    @ldap_settings = current_customer.settings.ldap_settings
  end

  def new
    @ldap_settings = current_customer.settings.ldap_settings.build
  end

  def create
    @ldap_settings = current_customer.settings.ldap_settings.new(ldap_settings_params)
    if @ldap_settings.save
      flash[:success] = t("settings.flash_msg_ldap.create_success")
      redirect_to edit_ldap_setting_path(@ldap_settings)
    else
      flash[:error] = "#{t('settings.flash_msg_ldap.create_failure')}: "\
                      "#{@ldap_settings.errors.full_messages.join(', ')}"
      render :new
    end
  end

  def edit; end

  def update
    if @ldap_settings.update(ldap_settings_params)
      flash[:success] = t("settings.flash_msg_ldap.update_success")
      redirect_to edit_ldap_setting_path(@ldap_settings)
    else
      flash[:error] = "#{t('settings.flash_msg_ldap.update_failure')}: "\
                      "#{@ldap_settings.errors.full_messages.join(', ')}"
      render :edit
    end
  end

  def destroy
    @ldap_settings.destroy
    if @ldap_settings.destroyed?
      flash[:success] = t("settings.flash_msg_ldap.destroy_success")
    else
      flash[:error] = @ldap_settings.errors.full_messages.join(", ")
    end
    redirect_to ldap_settings_path
  end

  def activate
    @ldap_settings.toggle(:enabled)
    if @ldap_settings.save
      flash[:success] = t("settings.flash_msg_ldap.update_success")
    else
      flash[:error] = @ldap_settings.errors.full_messages.join(", ")
    end
    redirect_to ldap_settings_path
  end

  private

  def check_policies
    @settings = current_customer.settings

    authorize @settings, :ldap_settings?
  end

  def load_ldap_settings
    settings = current_customer.settings
    @ldap_settings = settings.ldap_settings.find(params[:id])
  end

  def ldap_settings_params
    params.require(:ldap_setting).permit(
      :server_name, :host, :port, :encryption, :uid, :base_dn, :filter, :bind_dn, :password,
      :email_key, :firstname_key, :lastname_key, :service_key, :function_key,
      :phone_key, :mobile_phone_key, :groups_key, :roles_key
    )
  end
end
