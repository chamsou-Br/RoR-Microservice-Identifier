# frozen_string_literal: true

# This controller is used for showing a login form when LDAP mode is activated
# see config/initializers/omniauth.rb
# There is a gotcha: since the oauth ldap provider is configured in an initializer,
# you'll have to restart the rails server to pick up any new changes to this controller.
# Otherwise rails won't see the changes, even in development environment.
class LoginsController < ApplicationController
  skip_before_action :authenticate_user!

  def new
    if current_customer.settings.ldap?
      @ldap_servers = current_customer.settings.ldap_settings.enabled
      @preferred_server = cookies[:preferred_ldap_server]
      render layout: "login_layout"
    else
      redirect_to root_path
    end
  end
end
