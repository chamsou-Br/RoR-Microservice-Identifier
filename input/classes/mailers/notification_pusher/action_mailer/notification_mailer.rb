# frozen_string_literal: true

# This file is based on the original found in the gem:
# notification-pusher-actionmailer-3.0.2/app/mailers/...
# .../notification_pusher/action_mailer/notification_mailer.rb
# Certain modifications are needed:
# * add `helper NotificationRendererHelper`
# * delete line: `render(layout: layout) unless layout.nil?`,
#     we want render with another layout to develop notfications in parallel.
# * add `format.html { render layout: layout }`

module NotificationPusher
  class ActionMailer
    class NotificationMailer < ApplicationMailer
      helper NotificationRendererHelper

      def bulk_email(notifications,
                     renderer: "bulkmailer", mail_options: {}, **kwargs)
        addressee_uniqueness?(notifications)

        @notifications = notifications
        @notification = notifications.first
        @renderer = renderer

        @user_locale = @notification.target.language.to_sym || I18n.locale
        frequency_string = "notifications.bulk.#{kwargs[:frequency]}"

        @hello = I18n.t("notifications.greeting",
                        locale: @user_locale,
                        to: @notification.target.name.full)
        @goodbye = I18n.t("#{frequency_string}_goodbye", locale: @user_locale)

        mail({
          subject: I18n.t("#{frequency_string}_subject", locale: @user_locale),
          to: @notification.target.email
        }.merge(mail_options)) do |format|
          format.html { render layout: "bulk_email" }
        end
      end

      # The argument action: needs to be passed and is used to call this
      # method. Because it is a key argument, the `_` cannot be used.
      #
      def entity(notification,
                 from:, to: nil, renderer: "actionmailer",
                 layout: nil, mail_options: {}, **_kwargs)

        # These two instance variables are used in "push.html.erb" or layout
        @notification = notification
        @renderer = renderer

        # These instance variables are used in `layout/notification.html.erb`,
        # `app/views/notifications/notification/_actionmailer.html.erb` and
        # the method `send_method` below.
        # More refactoring is possible.
        #
        @to_user = (to || notification.target)
        @user_locale = notification.target.language.to_sym || I18n.locale
        @full_url = notification.object.full_url
        @comment = notification.metadata[:comment]

        send_email(mail_options, layout, from, to)
      end

      def send_email(mail_options, layout, from, to)
        subject = t(
          "notifications.#{@notification.metadata[:category]}.subject",
          entity: @notification.object_type.constantize.model_name.human(
            locale: @user_locale
          ),
          locale: @user_locale
        )

        mail({
          subject: subject,
          to: to || @notification.target.email,
          from: from
        }.merge(mail_options)) do |format|
          format.html { render layout: layout }
        end
      end

      def addressee_uniqueness?(notifications)
        email_addresses = notifications.map(&:target).map(&:email).uniq
        if email_addresses.count > 1
          raise ArgumentError,
                "Bulk notification emails must all be sent to the same target "\
                "but received #{email_addresses} as targets."
        else
          true
        end
      end
    end
  end
end
