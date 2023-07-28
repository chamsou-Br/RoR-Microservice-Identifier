# frozen_string_literal: true

module Users
  class SamlSessionsController < Devise::SamlSessionsController
    before_action :check_policies

    def new
      request = OneLogin::RubySaml::Authrequest.new
      # RelayState permet une redirection lorsqu'on a un problème. Il permet par exemple
      # d'éviter les boucles infinies
      action = request.create(saml_config, "RelayState" => user_sso_session_path)
      redirect_to action
    rescue OpenSSL::X509::CertificateError
      @error = :certificate_error
      render "devise/shared/sso_login_info_or_error"
    end

    def confirm_sign_in
      render "devise/shared/sso_login_info_or_error"
    end

    def create
      logger.info ">>>>>>>>>>>>>>>> params: #{params}"
      response = OneLogin::RubySaml::Response.new(params[:SAMLResponse], settings: saml_config)

      logger.info ">>>>>>>>>>>>>>>> response.inspect: #{response.inspect}"
      logger.info "response.errors: #{response.errors.inspect}"

      if response.is_valid?
        sign_in_user_with_saml(response)
      else
        flash[:error] = "Invalid response: #{response.errors.inspect}"
        redirect_to saml_confirm_sign_in_path
      end
    end

    protected

    def after_sign_in_path_for(resource)
      return edit_metadata_users_path if @created_user_via_sso

      super
    end

    private

    def sign_in_user_with_saml(response)
      log_sso_details(response)

      # TODO: check if this is used anywhere
      session[:userid] = response.nameid
      session[:attributes] = response.attributes

      process_response(response)

      if @user.present? && @user.persisted? && @user.active_for_authentication?
        @user.accept_pending_invitation if @user.pending_invitation?
        flash[:notice] = I18n.t("devise.sessions.signed_in")
        sign_in_and_redirect @user, event: :authentication
      else
        render "devise/shared/sso_login_info_or_error"
      end
    end

    def process_response(response)
      normalized_attrs = SamlNormalizerService.new(response.attributes, current_customer).normalize
      saml_data = ExternalUsersService.new(normalized_attrs, current_customer).process_data

      @user = saml_data[:user]
      @error = saml_data[:error]
      @created_user_via_sso = saml_data[:created_user] || false
    end

    def log_sso_details(response)
      logger.info "response.attributes: #{response.attributes}"
      logger.info "sso @user: #{@user.inspect}"
      logger.info "sso @error: #{@error}"
      logger.info "sso @created_user_via_sso: #{@created_user_via_sso}"
    end

    # rubocop:disable Metrics/AbcSize
    def saml_config(_idp_entity_id = nil)
      sso_settings = current_customer.settings.sso_settings

      settings = OneLogin::RubySaml::Settings.new
      # PB SSO pour Bouygues (BYUK), venant de 'requestedAuthnContext'.
      # Tentative de résolution en laissant la valeur par defaut à 'authn_context'
      # settings.authn_context                      = ""
      settings.assertion_consumer_service_binding = "urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST"
      settings.name_identifier_format             = "urn:oasis:names:tc:SAML:2.0:nameid-format:transient"
      settings.idp_slo_target_url                 = sso_settings.slo_url
      settings.idp_sso_target_url                 = sso_settings.sso_url

      cert = OpenSSL::X509::Certificate.new(sso_settings.cert_x509).to_pem.to_s.chomp
      # FIXME: `certificate` and `idp_cert` appear to be certs reflecting
      #   different entities.  Likely only one of these need be used.
      settings.certificate = cert
      settings.idp_cert = cert

      # IDP ACS URL (if activated recipient's IDP must be filled)
      settings.assertion_consumer_service_url = URI.join(
        current_customer.absolute_domain_name, "users/saml/auth"
      ).to_s

      # IDP Audience
      # FIXME: Should be using `sp_entity_id` as `issuer` is now deprecated
      # settings.sp_entity_id = "#{current_customer.absolute_domain_name}/users/saml/metadata"
      settings.issuer = "#{current_customer.absolute_domain_name}/users/saml/metadata"

      settings
    end
    # rubocop:enable Metrics/AbcSize

    def check_policies
      authorize current_customer.settings, :sso_pages?
    end
  end
end
