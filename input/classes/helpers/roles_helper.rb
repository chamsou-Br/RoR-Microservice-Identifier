# frozen_string_literal: true

module RolesHelper
  def humanize_role_type(type)
    I18n.t("helpers.roles.humanize_role_type.#{type}")
  end

  def humanize_delete_error(role_titles)
    error_message = I18n.t("controllers.roles.errors.delete")
    error_message << "<br/><br/>"
    error_message << "<div style='text-align:left;margin-left:5em;'>"
    error_message << role_titles.map { |x| "- #{x}" }.join("<br/>")
    error_message << "</div>"
    error_message
  end
end
