# frozen_string_literal: true

module GraphsHelper
  FONT_SUBSTITUTES = {
    "Arial" => "Liberation Sans",
    "Times New Roman" => "Liberation Serif",
    "Courier New" => "Liberation Mono"
  }.freeze

  def humanize_graph_type(type)
    I18n.t(type, scope: "helpers.graphs.humanize_graph_type")
  end

  def status_class_for(entity)
    "#{entity.state}_class"
  end

  def graph_icon_url(graph)
    asset_path("graph/d-graph-#{graph.type}.svg")
  end

  def options_for_graph_level(levels = nil)
    levels = Graph.levels.map(&:to_s) if levels.nil?
    levels << "tree" if levels.include?("3")
    attr_level = t(".attributs.level.to_s")
    options_for_select(
      levels.each.map do |level|
        if level == "tree"
          ["#{attr_level} #{t('.attributs.level.tree')}", level]
        else
          ["#{attr_level} #{level} #{t(".attributs.#{level}.classic")}", level]
        end
      end
    )
  end

  def options_for_review_reminders(graph)
    options_for_select(
      Groupgraph.review_reminders.map do |k, v|
        [I18n.t("activerecord.attributes.groupgraph.review_reminders.#{k}"), v]
      end,
      Groupgraph.review_reminders[graph.groupgraph.review_reminder]
    )
  end

  # rubocop:disable Style/ColonMethodCall
  def lined_format(attr)
    return "" if attr.nil?

    attr.split(/\n/).map { |s| CGI::escapeHTML(s) }.join("<br/>").html_safe
  end
  # rubocop:enable Style/ColonMethodCall

  def svg_printable(svg)
    absolute = "#{request.protocol}#{request.host_with_port}"
    absolute += ":#{Settings.server.port}" unless Settings.server.port.nil?
    Rails.logger.info("svg_printable absolute =  #{absolute}")

    # rubocop:disable Style/StringConcatenation
    svg = svg.gsub("/assets/", "#{absolute}/assets/")
    svg = svg.gsub(
      "/uploads/graph_background/", "#{absolute}/uploads/graph_background/"
    )
    svg = svg.gsub(
      'xlink:href="/resources/', 'xlink:href="' + absolute + "/resources/"
    )
    svg = svg.gsub(
      'xlink:href="/gallery/', 'xlink:href="' + absolute + "/gallery/"
    )
    # rubocop:enable Style/StringConcatenation

    svg = graph_font_substitution(svg, FONT_SUBSTITUTES)
    raw svg
  end

  private

  def graph_font_substitution(svg, font_substitutes)
    search_list = font_substitutes.keys.join("|")
    # search only tag '<text>' containing target fonts
    texts = svg.to_enum(:scan, /<text.*?(#{search_list}).*?>/).map do
      Regexp.last_match\
    end

    # stores offset according to translation when applying substitution
    offset = 0
    texts.each do |m|
      start, last = m.offset(0)
      found = m[1]
      # substitute old font by the new one
      new_string = m.to_s.gsub(found, font_substitutes[found])
      old_length = last - start
      svg[start + offset...last + offset] = new_string
      offset += new_string.length - old_length
    end
    svg
  end
end
