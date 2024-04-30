# frozen_string_literal: true

module DirectoriesHelper
  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity
  # rubocop:disable Metrics/MethodLength, Metrics/PerceivedComplexity
  def child_image_url(child, size = nil)
    size = "48x48" if size.nil?
    if child.instance_of?(Document)
      img = if child.url.blank?
              if child.is_msword?
                image_tag("referential/file-word.svg", size: size)
              elsif child.is_pdf?
                image_tag("referential/file-pdf.svg", size: size)
              elsif child.is_excel?
                image_tag("referential/file-excel.svg", size: size)
              elsif child.is_ppt?
                image_tag("referential/file-power.svg", size: size)
              elsif child.is_image?
                image_tag("referential/file-image.svg", size: size)
              elsif child.is_audio?
                image_tag("referential/file-sound.svg", size: size)
              elsif child.is_video?
                image_tag("referential/file-video.svg", size: size)
              else
                image_tag("referential/file-other.svg", size: size)
              end
            else
              image_tag("referential/file-url.svg", size: size)
            end
    elsif child.instance_of?(Graph)
      img = image_tag("graph/d-graph-#{child.type}.svg", size: size)
    elsif child.instance_of?(Role)
      # ['intern', 'extern', 'unit']
      img = image_tag("roles/#{child.type}-role.svg", size: size)
    elsif child.instance_of?(Resource)
      img = image_tag("referential/all-average-icon.svg", size: size)
    elsif child.instance_of?(Tag)
      img = image_tag("tag/tag-icon.svg", size: size)
    end

    img
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity
  # rubocop:enable Metrics/MethodLength, Metrics/PerceivedComplexity

  def directory_name(directory)
    directory.parent_id.nil? ? I18n.t("layouts.snapmenu.directory_tree") : directory.name
  end

  def count_elements(child)
    policy_scope(child).count
  end

  def child_graph_mini_thumb(graph_type)
    image_tag("graph/d-graph-#{graph_type}.svg", size: "18x18")
  end

  # rubocop:disable Metrics/MethodLength
  def directory_favor_links(child)
    class_name = child.class.name.downcase
    favor_path = "favor_one_#{class_name}_path"
    unfavor_path = "unfavor_one_#{class_name}_path"
    return unless child.respond_to?(:likers) && respond_to?(favor_path) && respond_to?(unfavor_path)

    favored = child.likers.include?(current_user)
    link_to(send(favor_path, child),
            remote: true,
            method: "post",
            id: "favor#{child.id}",
            style: "display: #{favored ? 'none' : 'inline'}",
            alt: t("views.add_favorites")) do
      content_tag(:i, class: "fa fa-star-o") {}
    end +
      link_to(send(unfavor_path, child),
              remote: true,
              method: "post",
              id: "unfavor#{child.id}",
              style: "display: #{favored ? 'inline' : 'none'}",
              alt: t("views.add_favorites")) do
        content_tag(:i, class: "fa fa-star") {}
      end
  end
  # rubocop:enable Metrics/MethodLength

  def directory_favored?(child)
    fav_list = []

    if child.instance_of?(Graph) ||
       child.instance_of?(Document) ||
       child.instance_of?(Resource) ||
       child.instance_of?(ProcessNotification)

      class_dcase = child.class.name.downcase
      fav_list    = current_user.send("favorites_#{class_dcase.pluralize}")
    end

    fav_list.include?(child)
  end

  def directory_dynasty(directory)
    directory = current_customer.root_directory if directory.nil?

    res  = "<div class='container-tree'>"
    res += "<ol class='tree'>"
    res += set_directory(directory.build_nested_hash)
    res += "</ol>"
    res += "</div>"
    res.html_safe
  end

  def humanize_state(state, publish = false)
    scope = "helpers.directories.humanize_state"
    states = {
      "new" => I18n.t("new", scope: scope),
      "verificationInProgress" => I18n.t("verification_in_progress", scope: scope),
      "approvalInProgress" => I18n.t("approval_in_progress", scope: scope),
      "approved" => if publish
                      I18n.t("approved.delayed_yes", scope: scope)
                    else
                      I18n.t("approved.delayed_no", scope: scope)
                    end,
      "applicable" => I18n.t("applicable", scope: scope),
      "deactivated" => I18n.t("deactivated", scope: scope),
      "archived" => I18n.t("archived", scope: scope)
    }
    states[state]
  end

  def humanize_date(long_date)
    I18n.l(long_date, format: :long)
  end

  def print_title_for(graphs, documents)
    count = graphs.count + documents.count
    formatted_date = I18n.l(Time.current, format: :file_export)

    return I18n.t("print.print.custom_title", count: count, short_date: formatted_date) if count != 1

    entity = graphs.any? ? graphs.first : documents.first
    I18n.t("print.print.custom_title",
           count: count,
           model_name: I18n.t("activerecord.models.#{entity.class.name.downcase}.one"),
           title: truncate_print_title(entity.title),
           short_date: formatted_date)
  end

  def truncate_print_title(title)
    return "" if title.blank?

    title[0..59]
  end

  def read_confirmation_send_notif_path_for(entity)
    send("send_read_confirmation_reminders_#{entity.class.name.downcase}_path", entity.id)
  end

  private

  def set_directory(directory_nested_hash, checked = true)
    directory = directory_nested_hash[:directory]
    directory_name = render_for_html(directory.name)
    res = "<li>"
    res += "<label for='#{directory_name.downcase}' id='#{directory.id}' >#{directory_name}</label>"
    res += "<input type='checkbox' #{checked ? 'checked' : ''} id='#{directory_name.downcase}' class='toggling' />"
    res += directory_children(directory_nested_hash)
    "#{res}</li>"
  end

  def directory_children(directory_nested_hash)
    children = directory_nested_hash[:children].sort { |a, b| a[:directory].name <=> b[:directory].name }
    res = ""
    if children.any?
      res += "<ol>"
      children.each do |directory_child|
        res += set_directory(directory_child, false)
      end
      res += "</ol>"
    end
    res
  end

  def build_tag_with_msg(msg)
    tag = '<p class="empty-block">'
    tag += msg
    tag += "</p>"
    tag.html_safe
  end
end
