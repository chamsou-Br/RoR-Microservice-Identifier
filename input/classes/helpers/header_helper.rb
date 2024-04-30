# frozen_string_literal: true

#
# Configurations for global header view in Store & Process
#
module HeaderHelper
  def header_helper_options
    helper_items = [online_help_item]
    return helper_items if current_customer.freemium?

    helper_items << referent_item if contact_referent.present?
    helper_items += power_user_items if current_user.power_user?

    helper_items
  end

  private

  def language_prefix
    current_user.language == "fr" ? "fr" : "not_fr"
  end

  def user_prefix
    current_user.power_user? ? "pu" : "u"
  end

  def contact_referent
    current_customer.settings.referent_contact
  end

  def online_help_item
    {
      link: GeneralSetting.getValueFromKey("help_#{language_prefix}_#{user_prefix}_online"),
      text: t("layouts.loginmenu.online_help")
    }
  end

  def referent_item
    {
      link: "mailto:#{contact_referent}",
      text: t("layouts.loginmenu.contact_referent")
    }
  end

  def power_user_items
    [contact_us_item, customer_space_item].compact
  end

  def contact_us_item
    return if GeneralSetting.getValueFromKey("help_#{language_prefix}_contact_us").blank?

    {
      link: GeneralSetting.getValueFromKey("help_#{language_prefix}_contact_us"),
      text: t("layouts.loginmenu.contact_us")
    }
  end

  def customer_space_item
    return if GeneralSetting.getValueFromKey("help_#{language_prefix}_customer_space").blank?

    {
      link: GeneralSetting.getValueFromKey("help_#{language_prefix}_customer_space"),
      text: t("layouts.loginmenu.customer_space")
    }
  end
end
