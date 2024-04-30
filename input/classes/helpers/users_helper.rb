# frozen_string_literal: true

module UsersHelper
  def humanize_user_gender(type)
    I18n.t(type, scope: "helpers.users.gender")
  end

  def humanize_user_mail_frequency(type)
    I18n.t(type, scope: "helpers.users.mail_frequency")
  end

  def humanize_user_mail_weekly_days
    res = []

    7.times do |i|
      res << [i, I18n.t(i, scope: "helpers.users.mail_weekly_days")]
    end

    res
  end

  def humanize_user_mail_weekly_day(user)
    humanize_user_mail_weekly_days[user.mail_weekly_day][1]
  end

  def humanize_user_mail_locale_hours
    res = []

    24.times do |i|
      res << [i, I18n.t(i, scope: "helpers.users.mail_locale_hours")]
    end

    res
  end

  def humanize_user_mail_locale_hour(user)
    humanize_user_mail_locale_hours[user.mail_locale_hour][1]
  end

  def humanize_user_time_zone(user)
    res = nil
    tz_array = ActiveSupport::TimeZone.all.collect { |t| [t.name, t.to_s] }
    tz_array.each do |tz|
      res = tz[1] if tz[0] == user.time_zone
    end

    res
  end

  def user_avatar(user, options = {})
    url = user_avatar_url(user, options)
    html = <<-HTML
      #{user_avatar_image_tag(url, user, options)}
    HTML

    html.html_safe
  end

  def user_avatar_url(user, options = {})
    if !user.avatar.blank?
      serve_avatar_user_path(user, version: options[:version])
    elsif !options[:profile].blank? && !options[:profile].picture_url.nil?
      options[:profile].picture_url
    else
      asset_path "new_ihm/#{user.gender}.svg"
    end
  end

  #
  # Image tag for the avatar of the given `user` with `options`.
  #
  # @param [String] url User's avatar URL
  # @param [User] user
  # @param [Hash{Symbol => Any}] options `<image>` tag options
  # @option options [String] :class HTML `class`
  # @option options [String] :id HTML `id`
  # @option options [Any] :profile
  # @option options [Any] :size
  #
  # @return [Any]
  #
  def user_avatar_image_tag(url, user, options = {})
    tag_options = {
      alt: user.name.full,
      class: options[:class],
      size: options[:size],
      title: user.name.full
    }

    if !user.avatar.blank?
      image_tag(url, **tag_options.merge(id: options[:id]))
    elsif !options[:profile].blank? && !options[:profile].picture_url.nil?
      image_tag(url, **tag_options)
    else
      image_tag(url, **tag_options)
    end
  end

  def humanize_user_profile(profile_type)
    I18n.t(profile_type, scope: "helpers.users.profile_type")
  end

  def humanize_improver_user_profile(profile_type)
    I18n.t(profile_type, scope: "helpers.users.improver_profile_type")
  end

  def user_profile_badge(user)
    url = user_profile_badge_url(user)
    return unless url

    profile_type_class = current_user.process_admin? ? "" : "no_ddown"
    image_tag(url, class: "user_profile_type #{profile_type_class}",
                   size: "24x24").html_safe
  end

  def user_profile_badge_url(user)
    asset_path("new_ihm/#{user.profile_type}-list-icon.svg")
  end

  def improver_user_profil_badge_url(user)
    asset_path("new_ihm/#{user.improver_profile_type}-list-icon-improver.svg")
  end

  def humanize_user_level(user)
    key = if user.deactivated?
            "deactivated"
          elsif user.valid_invitation?
            "inviting"
          elsif user.power_user?
            "power"
          elsif user.process_user?
            "simple"
          end

    I18n.t(key, scope: "activerecord.attributes.user.level") unless key.blank?
  end

  def humanize_user_language(current_language)
    I18n.t(current_language, scope: "helpers.users.language")
  end

  def translate_errors(msg)
    res = case msg
          when I18n.t("helpers.users.errors.freemium_customer")
            build_msg("freemium_customer_msg")
          when I18n.t("helpers.users.errors.paying_customer.max_power_user")
            build_msg("max_power_user_reached")
          when I18n.t("helpers.users.errors.paying_customer.max_simple_user")
            build_msg("max_simple_user_reached")
          else
            msg
          end

    res.html_safe
  end

  def check_if_freemium(user)
    user.customer.freemium? && !user.customer.internal?
  end

  def show_freemium_msg
    build_msg("freemium_customer_msg").html_safe
  end

  def admin_tools(user)
    return unless policy(user).create?

    if user.deactivated?
      link_to(restore_user_path(user), remote: true, method: "post") do
        button_tag(I18n.t("helpers.users.buttons.content.user_reactivation"), class: %w[pushdetails restore-user])
      end
    elsif user.valid_invitation?
      link_to(invite_user_path(user), remote: true, method: "post") do
        button_tag(I18n.t("helpers.users.buttons.content.send_back_invitation"), class: %w[pushdetails reinvite-user])
      end
    end
  end

  def users_list_link(label)
    link_to(users_path) { content_tag(:span, label) }
  end

  private

  def build_msg(msg_key)
    str = ""
    str += "<div class=\"error_messages directory_name warning\" >"
    str += "<p>"
    str += I18n.t(msg_key.to_s, scope: "helpers.users.errors.messages")
    str += "</p>"
    # rubocop:disable all
    str += "<a class=\"error_customer_freemium\" href=\"#{(!current_user.nil? && current_user.language == "fr") ? "http://secure.inescrm.com/maxhd/helpdesk.dll/portail?AMKldMLAxI3ZMFYxG2NqljQBMKBoOKxiDLBVOLBdNE$$2NqljQ7QaNdLr7ZNXoo2NqljQ7Qb-jLr7ZNXol2NqljQ9P43iNrJVNqIxFZ6$" : "https://secure.inescrm.com/maxhd/helpdesk.dll/portail?AMKldMLAxI3ZMFYxG2NqljQBMKBoOKxiDLBVOLBdNE$$2NqljQ7QaNdLr7ZNXop2NqljQ7Qb-jLr7ZNXom2NqljQ9P43iNrJVNqIxFZ6$"}\">#{I18n.t('contact_us', scope: 'helpers.users.errors.messages')}</a>"
    # rubocop:enable all
    str += "</div>"
    str
  end
end
