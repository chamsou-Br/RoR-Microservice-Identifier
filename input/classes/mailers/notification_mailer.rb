# frozen_string_literal: true

# TODO: Refactor `NotificationMailer` into smaller, reusable methods
class NotificationMailer < ApplicationMailer
  helper :application, :users, :notifications, :customerSetting

  include NotificationsHelper

  class << self
    #
    # A logo path for the given `customer` or a default Pyx4 logo path if no
    # `customer` is provided
    #
    # @param [Customer, nil] customer
    # @return [String]
    #
    def logo_for(customer = nil)
      if !customer.nil? &&
         !customer.settings.logo.blank? &&
         customer.settings.logo_usage == "application_print_mail"
        "public/#{customer.settings.logo.url}"
      else
        "app/assets/images/mails/logo.gif"
      end
    end
  end

  #
  # Sends the given `notification`
  #
  # @param [NewNotification, ProcessNotification] notification
  # @param [String, nil] extra
  # @return [ActionMailer::MessageDelivery]
  # @todo Refactor `notify_user` into smaller private methods
  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  def notify_user(notification, extra = "")
    logger.debug "In NotificationMailer.notify_user"
    @notification = notification
    # TODO: Use a centralized way of getting the target from a notification of
    #       any type.  Also, why is one branch returning a {String} and the
    #       other returning a {User}?
    @user = if notification.is_a?(ProcessNotification)
              notification.receiver.firstname
            else
              notification.to
            end
    @title = notification_subject(notification)
    @recipient_locale = notification_i18n_locale(notification)
    @greetings_message = I18n.t(
      "controllers.notifications.mailer.notify_user.greetings_goodbye",
      locale: @recipient_locale
    )
    @extra = extra
    # TODO: Use a centralized way of getting the target's customer from a
    #       notification of any type
    @customer = if notification.is_a?(ProcessNotification)
                  notification.receiver.customer
                else
                  notification.customer
                end
    load_attachments(@customer)

    # FIXME: This check should raise if `notification` does not respond to `#to`
    #        like {ProcessNotification} which uses `#receiver` instead.
    return if notification.to.deactivated? || !notification.to.invitation_token.nil?

    logger.info("Sending to #{notification.to.email} a #{notification.category} notification")

    mail(subject: @title, to: notification.to.email) do |format|
      format.html { render layout: "mail" }
    end
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

  def scheduled_notify_user(user, notifications)
    logger.debug "--> In NotificationMailer.scheduled_notify_user."
    @user = user
    @customer = user.customer
    @recipient_locale = user.language
    load_attachments(@customer)
    @notifications = notifications
    @title = "[#{@customer.nickname}] " + I18n.t(
      "controllers.notifications.mailer.scheduled_mail.title",
      locale: @recipient_locale
    )
    @greetings_message = I18n.t(
      user.mail_frequency,
      scope: %i[controllers notifications mailer scheduled_notify_user
                greetings_goodbye],
      locale: @recipient_locale
    )
    logger.info("--> Sending scheduled_mail to #{user.email}")

    mail(subject: @title, to: user.email) do |format|
      format.html { render layout: "mail" }
    end
  end

  def inform_user(user)
    account_reactivated = I18n.t(
      "controllers.notifications.mailer.inform_user.title",
      instance_name: user.customer.nickname
    )
    load_attachments(user.customer)
    @datas = {
      "title" => account_reactivated,
      "customer_url" => user.customer.url,
      "customer_absolute_url" => user.customer.absolute_domain_name
    }
    @user = user
    @title = account_reactivated
    @greetings_message = I18n.t(
      "controllers.notifications.mailer.inform_user.greetings_goodbye"
    )

    mail(subject: @title, to: user.email) do |format|
      format.html { render layout: "mail" }
    end
  end

  def send_emergency_access(user)
    I18n.t("controllers.notifications.mailer.send_emergency_access.title")
    @user = user
    load_attachments(@user.customer)
    subject = "[#{user.customer.nickname}] " + I18n.t("controllers.notifications.mailer.send_emergency_access.title")
    @datas = {
      "title" => subject,
      "customer_url" => user.customer.url,
      "emergency_token" => user.emergency_token
    }

    mail(subject: subject, to: user.email) do |format|
      format.html { render layout: "mail" }
    end
  end

  def inform_salesman(signup)
    freemium_account_created = I18n.t("controllers.notifications.mailer.inform_salesman.title")
    @customer = signup
    load_attachments(@customer)
    @user = @customer.users.first
    @title = freemium_account_created
    @greetings_message = I18n.t("controllers.notifications.mailer.inform_salesman.greetings_goodbye")
    if @customer.newsletter
      @newsletter_message = I18n.t("controllers.notifications.mailer.inform_salesman.newsletter_message")
    end

    mail(subject: @title, to: "info.commerce@pyx4.com") do |format|
      format.html { render layout: "mail" }
    end
  end

  def send_stats
    load_attachments

    @title = I18n.t("controllers.notifications.mailer.send_stats.title")

    @freemium_stats = Customer.freemium_stats_by_week
    last_week_stats = @freemium_stats.delete(:last_week)

    @last_week_freemium_created_count = last_week_stats.nil? ? 0 : last_week_stats[:count]
    @last_week_freemium_active_count = last_week_stats.nil? ? 0 : last_week_stats[:active]

    # TODO: Use an environment variable read into `Settings` instead of
    #       hardcoded email addresses
    receiver = if Rails.env.production?
                 "info.commerce@pyx4.com"
               else
                 "support@dev.qualiproto.fr"
               end

    mail(from: %("Qualipso #{Rails.env}" <#{self.class.default[:from]}>),
         subject: @title,
         to: receiver) do |format|
      format.html { render layout: "mail" }
    end
  end

  def self.send_stats_to_salesman
    send_stats.deliver_now
  end

  private

  #
  # Assigns inline mail attachments customized for the given `customer` using
  # Pyx4 defaults if no `customer` is provided.
  #
  # @param [Customer, nil] customer
  # @return [void]
  # @see logo_for
  #
  def load_attachments(customer = nil)
    SOCIAL_MEDIA_LOGOS
      .merge(logo: self.class.logo_for(customer))
      .transform_keys { |name| "#{name}.gif" }
      .transform_values { |path| File.read(Rails.root.join(path)) }
      .each { |name, contents| attachments.inline[name] = contents }
  end
end
