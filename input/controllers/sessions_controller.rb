# frozen_string_literal: true

class SessionsController < Devise::SessionsController
  def setup
    use_customer_ldap_params if current_customer.settings.ldap?
    head :not_found
  end

  def new
    case current_customer.settings.authentication_strategy
    when "database"
      initialize_devise_session
    when "saml"
      redirect_to saml_confirm_sign_in_path
    when "ldap"
      redirect_to user_ldap_omniauth_authorize_path
    else
      raise ArgumentError, I18n.t("controllers.settings.authentication_strategy.unknown")
    end
  end

  def destroy
    case current_customer.settings.authentication_strategy
    when "database", "ldap"
      destroy_devise_session
    when "saml"
      redirect_to destroy_user_sso_session_path
    else
      raise ArgumentError, I18n.t("controllers.settings.authentication_strategy.unknown")
    end
  end

  private

  def use_customer_ldap_params
    %i[host port uid encryption filter bind_dn password].each do |setting|
      request.env["omniauth.strategy"].options[setting] = ldap_settings.send(setting)
    end
    # this is an edge case. ActiveRecord has a reserved :base attribute that
    # we don't want to use as field on a table, but OAuth ldap strategy has a :base option
    # we want to set up
    request.env["omniauth.strategy"].options[:base] = ldap_settings.base_dn
  end

  # When a user opens the ldap login page for the first time
  # we don't know yet which server they will use, so we need a dumb setting
  # to get to the OAuth Request phase for this first time
  def ldap_settings
    @ldap_settings ||= if params[:server].present?
                         current_customer.settings.ldap_settings.enabled.find(params[:server])
                       else
                         current_customer.settings.ldap_settings.enabled.first!
                       end
  end

  def initialize_devise_session
    self.resource = resource_class.new(sign_in_params)
    clean_up_passwords(resource)
    yield resource if block_given?
    respond_with(resource, serialize_options(resource))
  end

  def destroy_devise_session
    signed_out = (Devise.sign_out_all_scopes ? sign_out : sign_out(resource_name))
    set_flash_message :notice, :signed_out if signed_out && is_flashing_format?
    yield if block_given?
    respond_to_on_destroy
  end
end
