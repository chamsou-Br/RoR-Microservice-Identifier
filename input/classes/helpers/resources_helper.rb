# frozen_string_literal: true

module ResourcesHelper
  # custom error message with list of linked resources to a graph
  def humanize_delete_error(resource_titles)
    error_message = I18n.t("resources.errors.delete")
    error_message << "<br/><br/>"
    error_message << "<div style='text-align:left;margin-left:5em;'>"
    error_message << resource_titles.map { |x| "- #{x}" }.join("<br/>")
    error_message << "</div>"
    error_message
  end
end
