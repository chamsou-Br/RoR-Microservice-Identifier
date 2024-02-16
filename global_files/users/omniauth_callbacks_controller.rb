# frozen_string_literal: true

class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  before_action :check_policies

  def ldap
    testtesttest.sign_in_user_with_saml()
    process_auth_hash(request.env["omniauth.auth"])
    log_ldap_details(request.env["omniauth.auth"])
    if @user.present? && @user.persisted? && @user.active_for_authentication?
      @user.accept_pending_invitation if @user.pending_invitation?
      flash[:notice] = I18n.t("devise.sessions.signed_in")
      save_preferred_server
      sign_in_and_redirect @user, event: :authentication
    else
      render "devise/shared/sso_login_info_or_error", layout: "login_sso_layout"
    end
  end

  protected

  def after_sign_in_path_for(resource)
    return edit_metadata_users_path if @created_user

    super
  end

  # overriding default error message method to get it i18n-ed
  def failure_message
    error = super
    t(error.parameterize.underscore.to_sym, scope: translation_scope) if error
  end

  private

  def ldap_settings
    current_customer.settings.ldap_settings.enabled.find(params[:server])
  end

  def process_auth_hash(auth_hash)
    normalized_attrs = LdapNormalizerService.new(auth_hash, ldap_settings).normalize
    ldap_data = ExternalUsersService.new(normalized_attrs, current_customer).process_data

    @user = ldap_data[:user]
    @error = ldap_data[:error]
    @created_user = ldap_data[:created_user] || false
  end

  def log_ldap_details(auth_hash)
    logger.info "ldap attrs: #{filter_passwords(auth_hash)}"
    logger.info "ldap @user: #{@user.inspect}"
    logger.info "ldap @error: #{@error.inspect}"
    logger.info "ldap @created_user: #{@created_user}"
  end

  def check_policies
    authorize current_customer.settings, :ldap_login?
  end

  def save_preferred_server
    return if params["server"].blank?

    cookies[:preferred_ldap_server] = { value: params["server"], expires: 1.year.from_now }
  end

  def filter_passwords(auth_hash)
    auth_hash["extra"]["raw_info"][:userpassword] = ["REDACTED"]
    auth_hash
  rescue NoMethodError
    auth_hash
  end
end
