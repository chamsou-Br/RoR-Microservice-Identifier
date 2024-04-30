# frozen_string_literal: true

module CustomerSettingHelper
  # Diplay entity logo or a default blank div.
  def entity_logo(entity, options = {})
    if entity.logo.blank?
      logo = "<div class='default_no_logo'></div>"
    else
      url = url_for(action: "serve_logo", version: options[:version])
      logo = image_tag(url, class: options[:class], id: options[:id], size: options[:size], style: options[:style])
    end
    html = <<-HTML
      #{logo}
    HTML

    html.html_safe
  end

  def img_from_gallery_for(entity, options = {})
    url = gallery_image_path(entity, version: options[:version])
    img = image_tag("#{url}&timestamp=#{Time.current.to_i}",
                    class: options[:class], id: options[:id], size: options[:size], style: options[:style])
    html = <<-HTML
      #{img}
    HTML

    html.html_safe
  end

  # Display customer logo or the default Pyx4 one.
  def customer_logo(settings, options = { referer: "application" })
    logo = image_tag("login/logo.svg",
                     class: options[:class], size: options[:size], alt: "Pyx4", style: options[:style])

    if !settings.logo.blank? &&
       (options[:referer] != "mail" ||
         (options[:referer] == "mail" && settings.logo_usage == "application_print_mail"))
      url = serve_logo_settings_path(settings, version: options[:version])
      logo = image_tag(url, size: options[:size], style: options[:style], class: options[:class])
    end

    html = <<-HTML
      #{logo}
    HTML

    html.html_safe
  end

  def customer_logo_url(customer, version = :show, options = { referer: "application" })
    # url = image_url('login/logo.svg')
    # url = image_url('mails/logo.gif')
    # url = request.protocol + request.host_with_port + path_to_image('mails/logo.gif')
    absolute = "#{request.protocol}#{request.host_with_port}"
    absolute += ":#{Settings.server.port}" unless Settings.server.port.nil?

    url = absolute + image_path("login/logo.png")
    # url = Rails.root.join('app/assets/images/mails/logo.gif')
    if !customer.settings.logo.blank? &&
       (options[:referer] != "mail" ||
         (options[:referer] == "mail" && customer.settings.logo_usage == "application_print_mail"))
      # url = serve_logo_settings_url(version: version)
      url = absolute + serve_logo_settings_path(version: version)
    end
    Rails.logger.info "---> url : #{url}"
    url
  end

  # rubocop:disable Metrics/MethodLength
  def basic_colors
    colors = ""
    colors += '<div class="colors_list">'
    colors += "<div>"
    colors += '<div class="master_color single_color" style="background:#ffffff;"></div>'
    colors += '<div class="tile" style="background-color:transparent;"></div>'
    colors += '<div class="single_color" style="background-color:#ffffff;"></div>'
    colors += '<div class="single_color" style="background-color:#e8e8e8;"></div>'
    colors += '<div class="single_color" style="background-color:#d1d1d1;"></div>'
    colors += '<div class="single_color" style="background-color:#bababa;"></div>'
    colors += '<div class="single_color" style="background-color:#a3a3a3;"></div>'
    colors += "</div>"
    colors += "</div>"
    colors += '<div class="colors_list">'
    colors += "<div>"
    colors += '<div class="master_color single_color" style="background-color:#000000;"></div>'
    colors += '<div class="single_color" style="background-color:#000000;"></div>'
    colors += '<div class="single_color" style="background-color:#303030;"></div>'
    colors += '<div class="single_color" style="background-color:#474747;"></div>'
    colors += '<div class="single_color" style="background-color:#5e5e5e;"></div>'
    colors += '<div class="single_color" style="background-color:#757575;"></div>'
    colors += '<div class="single_color" style="background-color:#8c8c8c;"></div>'
    colors += "</div>"
    colors += "</div>"

    html = <<-HTML
      #{colors}
    HTML

    html.html_safe
  end
  # rubocop:enable Metrics/MethodLength

  def connector_required_param?(attr)
    Mappable::REQUIRED_ATTRS.map { |sub_attr| "#{sub_attr}_key".to_sym }.include?(attr)
  end

  def connector_field_i18n_base(setting)
    base = setting.class.to_s.underscore
    "activerecord.attributes.#{base}"
  end

  def ldap_tab_class(current_page)
    if %w[ldap_settings_edit ldap_settings_index ldap_settings_new].include?(current_page)
      "active"
    else
      ""
    end
  end
end
