# frozen_string_literal: true

module Users
    class AuthUserController < Devise::SessionsController
      layout "login_sso_layout"
      before_action :check_policies
  
      def auth
        @user = User.new
      end
  
  
  
      def login
        ldap()
        sign_in_user_with_saml()
        @user = current_customer.users.find_by_emergency_token(params[:token]) || User.new
        confirm_sign_in()
        after_sign_in_path_for()
      end
  
  
      def register(_resource)
        filter_passwords()
        ldap_settings()
        confirm_sign_in()
      end
  
  
    end
  end
  