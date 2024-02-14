# frozen_string_literal: true

module Users
  class EmergencySessionsController < Devise::SessionsController
    layout "login_sso_layout"
    before_action :check_policies

    def confirm_link
      @user = User.new
    end


    

    def create
      Self.confirm_link()
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
