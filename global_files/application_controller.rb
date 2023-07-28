# frozen_string_literal: true

class ApplicationController < ActionController::Base
  protect_from_forgery
  include ApplicationHelper
  include Pundit
  include SearchException

  # @!method current_user
  #   The currently signed-in user or `nil` if the user is not signed in
  #   @return [User, nil]

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized
  rescue_from I18n::ArgumentError, with: :notify_missing_translation

  helper_method :host, :current_customer
  before_action :set_locale
  before_action :validate_host, :authenticate_user!
  before_action :set_time_zone, :mailer_set_url_options
  before_action :set_gon
  before_action :set_paper_trail_whodunnit
  before_action :set_raven_context

  skip_before_action :verify_authenticity_token

  before_action :configure_permitted_parameters, if: :devise_controller?
  after_action :allow_iframe

  protected

  def sanitize_this(text)
    ActionController::Base.helpers.render_for_html(text)
  end

  private

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:invite) do |u|
      u.permit(:email, :firstname, :lastname, :profile_type,
               :improver_profile_type)
    end
  end

  def respond_bip_error(obj)
    render json: obj.errors, status: :unprocessable_entity
  end

  def mailer_set_url_options
    ActionMailer::Base.default_url_options[:host] = request.host_with_port
  end

  def default_url_options
    { host: request.host }
  end

  def flash_x_success(message)
    return if message.nil?

    if request.xhr?
      response.headers["X-Flash-Success"] = message.encode("ISO-8859-1")
    else
      flash[:success] = message
    end
  end

  def flash_x_warn(message)
    return if message.nil?

    if request.xhr?
      response.headers["X-Flash-Warn"] = message.encode("ISO-8859-1")
    else
      flash[:warn] = message
    end
  end

  def flash_x_error(message, status = nil)
    return if message.nil?

    if request.xhr?
      response.headers["X-Flash-Error"] = message.encode("ISO-8859-1")
      render body: nil, status: status if status
    else
      flash[:error] = message
    end
  end

  def user_not_authorized
    flash[:error] = I18n.t("controllers.application.not_authorized")
    redirect_to request.headers["Referer"] || root_path
  end

  def host
    request.host
  end

  def validate_host
    # rubocop:disable Style/IfUnlessModifier, Style/GuardClause
    if request.subdomain != Settings.server.admin_subdomain && current_customer.nil?
      redirect_to "/404.html" and return
    end
    # rubocop:enable Style/IfUnlessModifier, Style/GuardClause
  end

  #
  # Returns the customer matching the current subdomain
  #
  # @return [Customer, nil]
  #
  def current_customer
    return if request.subdomain == Settings.server.admin_subdomain

    begin
      return @current_customer if defined?(@current_customer)

      @current_customer = Customer.find_by!(url: request.host)
    rescue ActiveRecord::RecordNotFound
      # rubocop:disable Style/IfUnlessModifier
      # Waiting for our 80 line reinforce cop.
      unless Rails.env.development? || Rails.env.test?
        redirect_to Settings.default_redirect.to_s and return
      end
      # rubocop:enable Style/IfUnlessModifier
    end
  end

  def allow_iframe
    return unless defined?(@current_customer)

    response.headers.except! "X-Frame-Options" if @current_customer.settings.allow_iframe?
  end

  # TODO: Simplify this logger nightmare
  # rubocop:disable Metrics/AbcSize
  def set_locale
    logger.debug "==> [in] set_locale : locale=#{I18n.locale}"
    locale = nil
    if request.subdomain != Settings.server.registration_subdomain
      if current_customer
        locale = current_customer.language.to_sym
        logger.debug "==> [into] set_locale : current_customer=#{current_customer.subdomain}, locale=#{locale}"
      end
      if current_user
        locale = current_user.language.to_sym
        logger.debug "==> [into] set_locale : current_user=#{current_user.name.full}, locale=#{locale}"
      end
    end
    if params[:locale]
      locale = params[:locale].to_sym
      logger.debug "==> [into] set_locale : params[:locale]=#{params[:locale]}, locale=#{locale}"
    end
    I18n.locale = locale if I18n.available_locales.include?(locale)
    logger.debug "==> [out] set_locale : available=#{I18n.available_locales.include?(locale)}, locale=#{locale}"
  end
  # rubocop:enable Metrics/AbcSize

  def set_gon
    return if current_user.nil?

    gon.push(env: Rails.env,
             current_user: {
               admin: current_user.process_admin?,
               improver_admin: current_user.improver_admin?,
               access_store: policy(current_user).access_store?,
               access_improver: policy(current_user).access_improver?,
               access_risk: policy(current_user).access_risk?
             })
  end

  def set_time_zone
    # Get default time zone
    locale_time_zone = Time.zone.name

    # TODO: Unwrap this modifier-form rescue
    # rubocop:disable Style/RescueModifier
    locale_time_zone = current_user.time_zone unless current_user.nil? rescue nil
    # rubocop:enable Style/RescueModifier

    Time.zone = locale_time_zone
  end

  # TODO: unused method? Task model doesn't exist
  def create_task(options = {})
    task = { from: current_user }.merge!(options)
    Task.generate_task(task)
  end

  def render_403
    render file: File.join(Rails.root, "public/403.html"), status: 403, layout: false
  end

  def not_found
    raise ActionController::RoutingError, "Not Found"
  end

  # TODO: Simplify using private methods for each conditional test
  # rubocop:disable Metrics/CyclomaticComplexity
  def notify_owner_if_max_graphs_and_docs_approaching(entity, mode_store = false)
    if mode_store && current_customer.max_graphs_and_docs_reached? && current_customer.owner.present?
      return urgently_notify(category: :max_graphs_and_docs_reached, entity: entity)
    end

    if current_customer.max_graphs_and_docs_reached? && !current_customer.owner.nil?
      return urgently_notify(category: :max_graphs_and_docs_reached, entity: entity)
    end

    return unless current_customer.graphs_and_docs_left == 5 && !current_customer.owner.nil?

    # A max_graphs_and_docs_reached - 5, envoi d'un message (story #137767141)
    urgently_notify(category: :max_graphs_and_docs_approching, entity: entity)
  end
  # rubocop:enable Metrics/CyclomaticComplexity

  # Sends a new urgent notification defaulting to current_customer and its owner
  def urgently_notify(category:, entity:, customer: current_customer, to: current_customer.owner)
    NewNotification.create_and_deliver(
      {
        customer: customer,
        category: category,
        entity: entity,
        to: to
      },
      "",
      true
    )
  end

  # Notify Mattermost channel for missing translations and re-raise to trigger
  # default I18n exception handling
  #
  # @param [I18n::Argument] exception Translation error being rescued
  def notify_missing_translation(exception)
    I18n::MissingKeyLogger.log_the(exception.message)
    raise exception.to_exception
  end

  # @see https://docs.sentry.io/platforms/ruby/context/
  def set_raven_context
    return if current_user.nil?

    Raven.user_context(
      email: current_user.email,
      customer: current_user.customer.url,
      sign_in_at: current_user.current_sign_in_at
    )
    Raven.tags_context(lang: current_user.language.to_sym)
    # Raven.tags_context(ip: current_user.current_sign_in_ip) # Check policy before use this field

    # We can add other important fields inside tags_context
    # It's also possible to use extra_context which support structured data
  end
end
