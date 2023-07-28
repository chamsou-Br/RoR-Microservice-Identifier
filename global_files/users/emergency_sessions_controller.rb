# frozen_string_literal: true

module Users
  class EmergencySessionsController < Devise::SessionsController
    layout "login_sso_layout"
    before_action :check_policies

    def confirm_link
      @user = User.new
    end

    def send_link
      @user = current_customer.users.find_or_initialize_by(email: params[:user][:email])

      if @user&.process_admin_owner?
        @emergency_link_sent = @user.set_emergency_token

        NotificationMailer.send_emergency_access(@user).deliver if @emergency_link_sent

        render "devise/shared/sso_login_info_or_error"
      else
        @user.errors.add :email, :not_owner_emergency
        render :confirm_link
      end
    end

    def create
      @user = current_customer.users.find_by_emergency_token(params[:token]) || User.new

      unless @user.process_admin_owner?
        @user.errors.add :base, :not_owner_or_emergency_token_invalid
        return render :confirm_link
      end

      unless @user.valid_emergency_token?
        @user.errors.add :base, :emergency_token_expired
        return render :confirm_link
      end

      @emergency_access = @user.clear_emergency_token

      flash[:success] = "Successfully sign in by using emergency access"
      sign_in_and_redirect @user, event: :authentication
    end

    protected

    def after_sign_in_path_for(_resource)
      return edit_sso_settings_path if current_customer.saml_auth_strategy?
      return ldap_settings_path if current_customer.ldap_auth_strategy?
    end

    private

    def check_policies
      if current_customer.saml_auth_strategy?
        authorize current_customer.settings, :sso_pages?
      else
        # no specific check for ldap by intent
        # it handles all the other cases, not only ldap
        authorize current_customer.settings, :ldap_login?
      end
    end
  end
end
