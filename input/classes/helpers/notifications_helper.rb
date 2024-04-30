# frozen_string_literal: true

# rubocop: disable all
module NotificationsHelper
  include ApplicationHelper
  include GraphsHelper

  #
  # Returns a subject text for the given notification
  #
  # @param [NewNotification, ProcessNotification] notification
  #
  # @return [String]
  #
  def notification_subject(notification)
    customer = notification.is_a?(ProcessNotification) ? notification.receiver.customer : notification.customer

    "#{"[#{customer.nickname}]"} #{t(:subject,
                                      scope: notification_i18n_scope(notification),
                                      locale: notification_i18n_locale(notification),
                                      entity: notification_i18n_entity(notification,
                                                                       notification_i18n_locale(notification)),
                                      title: notification.entity_title,
                                      from: notification.from ? notification.from.name.full : '',
                                      to: notification.to.name.full)}"
  end

  #
  # Returns a body text for the given notification
  #
  # @param [NewNotification, ProcessNotification] notification
  # @param [Hash] options
  # @option options [Boolean, nil] :absolute
  # @param [Hash] extra
  # @option extra [String] :accept_link
  # @option extra [String] :customer_service
  # @option extra [String] :reject_link
  #
  # @return [String]
  #
  def notification_body(notification, options = {}, extra = {})
    customer = notification.is_a?(ProcessNotification) ? notification.receiver.customer : notification.customer
    if notification.is_a?(NewNotification)
      routes = Rails.application.routes.url_helpers
      url = routes.follow_notification_path(notification)
      if options.key?(:absolute) && options[:absolute].is_a?(TrueClass)
        url = routes.follow_notification_url(notification, host: notification.customer.url)
      end

      Rails.logger.info("notification.category=#{notification.category}")
      case notification.category
      when 'connection_request', 'connection_established'
        t(:body,
          scope: notification_i18n_scope(notification),
          locale: notification_i18n_locale(notification),
          customer_source: extra[:customer_source],
          accept_link: extra[:accept_link],
          reject_link: extra[:reject_link])
      else
        res = if notification.entity_type == 'Reminder' && notification.entity.nil?
                t(:changed,
                  scope: notification_i18n_scope(notification),
                  locale: notification_i18n_locale(notification),
                  from: notification.from ? notification.from.name.full : '',
                  to: notification.to.name.full)
              else
                t(:body,
                  scope: notification_i18n_scope(notification),
                  locale: notification_i18n_locale(notification),
                  from: notification.from ? notification.from.name.full : '',
                  to: notification.to.name.full,
                  entity: notification_i18n_entity(notification, notification_i18n_locale(notification)).downcase,
                  link: ActionController::Base.helpers.link_to(url) { ActionController::Base.helpers.render_for_html(notification.entity_title) },
                  duration: notification.entity.is_a?(Reminder) ? notification.entity.duration_in_days : '',
                  instance_url: customer.url)
              end

        if need_body2?(notification)
          res += t(:body2,
                   scope: notification_i18n_scope(notification),
                   locale: notification_i18n_locale(notification),
                   estimated_closed_at: notification.entity.is_a?(Act) ? l(notification.entity.estimated_closed_at.to_date) : '')
        end

        if notification.option(:with_roles) && !notification.notification_roles.nil?
          roles_sentence = notification.notification_roles.collect do |key|
            t(key, scope: %i[activerecord attributes notification roles], locale: notification_i18n_locale(notification))
          end.to_sentence(locale: notification_i18n_locale(notification))
          res << '<br/>'
          unless roles_sentence.blank?
            res << t(:with_roles,
                     scope: notification_i18n_scope(notification),
                     locale: notification_i18n_locale(notification),
                     roles: roles_sentence)
          end
        end
        return res
      end
    elsif notification.is_a?(ProcessNotification)
      notification.message
    end
  end

  def need_body2?(notification)
    # Cas particulier des notif sur les Act, il faut la estimated_closed_at si elle est renseignée.
    if (notification.realize_act? || notification.realize_act_from_event? || notification.realize_act_to_author? || notification.realize_act_to_author_and_owner? || notification.realize_act_to_owner?) &&
       notification.entity.is_a?(Act) &&
       !notification.entity.estimated_closed_at.nil?
      true
    else
      false
    end
  end

  # TODO: remove this once all reference to it are removed
  def notification_type(notification)
    notification.notification_type
  end

  def notification_i18n_scope(notification)
    [:activerecord, :attributes, :notification, :category, notification.category]
  end

  def notification_i18n_locale(notification)
    (notification.to.nil? ? current_customer.language : notification.to.language).to_sym
  end

  def notification_i18n_entity(notification, locale = nil)
    entity = notification.entity
    entity_class = entity.class.equal?(Contribution) ? entity.contributable.class : entity.class

    if locale.nil?
      t(entity_class.name.downcase, scope: %i[activerecord models], count: 1)
    else
      t(entity_class.name.downcase, scope: %i[activerecord models], locale: locale, count: 1)
    end
  end

  # Generating suitable extra message for a given notification category
  # return HTML to be displayed in the mail notification
  # params
  # => notification: the notification object
  # => extra: the extra message to display as string
  def generate_extra_html_message(notification, extra)
    case notification.category
    when "new_contribution"
      if notification.from
        thumb = Rails.root.join("public/#{notification.from.avatar_url(:thumb)}")
        if File.exist?(thumb) && File.file?(thumb)
          attachments.inline['avatar.jpg'] = File.read(thumb)
        else
          attachments.inline['avatar.svg'] = File.read(Rails.root.join("app/assets/images/new_ihm/#{notification.from.gender}.svg"))
        end
      else
        attachments.inline['avatar.svg'] = File.read(Rails.root.join("app/assets/images/l-header/pyx-mini-blue.svg"))
      end
      contrib_extra_message = content_tag(:td, valign: 'top', class: 'bodyContent', style: '{width:40px;}') do
        if attachments['avatar.jpg'].nil?
          image_tag(attachments['avatar.svg'].url, width: "40", height: "40", class: "avatar")
        else
          image_tag(attachments['avatar.jpg'].url, width: "40", height: "40", class: "avatar")
        end
      end
      contrib_extra_message << content_tag(:td, valign: 'top', class: 'bodyContent contrib') do
        content_tag(:p, class: 'contribution_msg') do
          content_tag(:em) do
            "\" #{lined_format(extra)} \"".html_safe
          end
        end
      end
    when /^(sent|verification|approval|publication|applicable)\w+(pilot|author|other)$/
      content_tag(:td, valign: 'top', class: 'bodyContent') do
        concat(content_tag(:h4) do
          I18n.t('graphs.historical.thead.news')
        end)
        concat(content_tag(:p) do
          content_tag(:em) do
            simple_format(extra, {}, sanitize: true)
          end
        end)
      end
    when "connection_request", "connection_established"
      content_tag(:td, valign: 'top', class: 'bodyContent') do
        content_tag(:p) do
          content_tag(:em) do
            t(:extra,
              scope: notification_i18n_scope(notification),
              locale: notification_i18n_locale(notification),
              customer_source: extra[:customer_source],
              customer_source_url: extra[:customer_source_url],
              link: extra[:link]).html_safe
          end
        end
      end
    else
      content_tag(:td, valign: 'top', class: 'bodyContent') do
        content_tag(:p) do
          content_tag(:em) do
            "\" #{lined_format(extra)} \"".html_safe
          end
        end
      end
    end
  end
end
# rubocop: enable all
