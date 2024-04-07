# frozen_string_literal: true

class SignupsController < ApplicationController
  layout false

  skip_before_action :validate_host, :authenticate_user!
  before_action :log_registration, only: :create
  before_action :set_signup, only: :create
  before_action :authorize_remote_host, only: :create

  def new
    logger.debug "--> params in new : #{params}"
    cookies.permanent.signed[:campaign] = params[:campaign] unless params[:campaign].nil?
    @signup = Signup.new
  end

  def create
    if @signup.save
      redirect_to generate_url(create_params[:success_url]) if create_params[:success_url]
    elsif create_params[:errors_url]
      redirect_to(
        generate_url(create_params[:errors_url], signup: signup_params,
                                                 error_messages: @signup.errors.messages,
                                                 previous_params: signup_params)
      )
    else
      render action: "new"
    end
  end

  private

  def generate_url(url, params = {})
    uri = URI(url.strip)
    uri.query = params.to_query
    uri.to_s
  end

  def remote_host
    request.referer&.split("?")&.first || request.remote_ip
  end

  def authorize_remote_host
    return if Signup.authorized_remote_register?(request.base_url, remote_host)
    return if Signup.authorized_token?(params[:signup_token])

    if params[:errors_url].present?
      redirect_to(
        generate_url(
          params[:errors_url],
          signup: signup_params,
          error_messages: "Remote register #{remote_host} not authorized !"
        )
      )
    else
      @signup.errors.add(:subdomain, "Remote register #{remote_host} not authorized !")
      render action: "new"
    end
  end

  def set_signup
    @signup = Signup.new(signup_params)
    @signup.campaign = cookies.permanent.signed[:campaign]
  end

  def log_registration
    logger.info "--> signup from : #{remote_host} to #{request.base_url}..."
  end

  def create_params
    params.permit(:errors_url, :success_url)
  end

  #
  # Sanitizes parameters for signing up new users
  #
  # @return [ActionController::Parameter] Permitted parameters for signing up
  #   new users
  #
  def signup_params
    permitted_params = params.require(:signup)
                             .permit(:contact_phone, :email, :firstname,
                                     :function, :language, :lastname,
                                     :newsletter, :subdomain)
    permitted_params[:newsletter] = "0" if permitted_params[:newsletter].blank?
    permitted_params
  end
end
