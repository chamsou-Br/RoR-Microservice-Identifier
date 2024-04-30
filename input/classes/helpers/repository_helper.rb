# frozen_string_literal: true

module RepositoryHelper
  def repository_dynasty(directory)
    res = "<div id=\"nestable3\" class=\"dd dd-repository\" >"
    res += "<ol class=\"dd-list\">"
    res += repository_dynasty_list(directory)
    res += "</ol>"
    res += "</div>"
    res.html_safe
  end

  def repository_content(directory)
    res = "<div id=\"repository-content\" data-id=\"#{directory.id}\" "\
          "class=\"dd repository-content\" data-snap-ignore=\"true\" >"
    res += "<ol class=\"repository-content-list\">"
    res += repository_content_list(directory)
    res += "</ol>"
    res += "</div>"
    res.html_safe
  end

  private

  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
  def repository_dynasty_list(directory)
    res = ""
    res += "<li data-snap-ignore=\"true\" data-type=\"directory\" "\
           "data-id=\"#{directory.id}\" class=\"dd-item dd3-item "\
           "collapse-left #{directory.root? ? 'root_directory' : ' '} "
    res += " current_item " if !@directory.nil? && @directory.id == directory.id
    res += " dd-nodrag\">"
    res += "<div class=\"dd-handle dd-nodrag dd3-nodrag\"> </div>"
    res += "<div class=\"dd3-content\">"
    res += "<span class=\"directory-name\" id=\"directory_name_#{directory.id}\">"
    res += "<span class=\"directory-name-label\">"\
           "<a href=\"" + directory_path(directory) + "\">#{directory.name}</a></span>"
    res += "</span>"
    res += "</div>"

    res += "<ol class=\"dd-list\" data-snap-ignore=\"true\" >" if directory_has_children?(directory)
    # Si le directory a des children, on lance la récursivité
    if directory.children.count.positive?
      directory.children.each do |child|
        res += repository_dynasty_list(child)
      end
    end
    # Si le directory a des graphs, on lance le listage des graphs
    res += graphs_list(directory) if directory.graphs.count.positive?
    # Si le directory a des documents, on lance le listage des documents
    res += documents_list(directory) if directory.documents.count.positive?
    res += "</ol>" if directory_has_children?(directory)

    res += "</li>"
    res
  end

  def repository_content_list(directory)
    res = ""
    res += "<li data-snap-ignore=\"true\" data-type=\"directory\" data-id=\"#{directory.id}\" "\
           "class=\"dd-item dd3-item collapse-left"\
           " #{directory.root? ? 'root_directory' : ' '} dd-nodrag\">"
    res += "<div class=\"dd-handle dd-nodrag dd3-nodrag\" style=\"display:none;\"> </div>"
    res += "<div class=\"dd3-content\" style=\"display:none;\">"
    res += "<span class=\"directory-name\" id=\"directory_name_#{directory.id}\">"
    res += "<span class=\"directory-name-label\">"\
           "<a href=\"" + directory_path(directory) + "\">#{directory.name}</a></span>"
    res += "</span>"
    res += "</div>"

    if directory.children.count.positive? || directory.graphs.count.positive? || directory.documents.count.positive?
      res += "<ol class=\"dd-list\">"
    end

    # listing du premier niveau de children
    if directory.children.count.positive?
      directory.children.each do |child_directory|
        res += "<li data-type=\"directory\" data-id=\"#{child_directory.id}\" "\
               "class=\"dd-item dd3-item collapse-left } dd-nodrag\">"
        res += "<div class=\"dd-handle dd-nodrag dd3-nodrag\"> </div>"
        res += "<div class=\"dd3-content\">"
        res += "<span class=\"directory-name\" id=\"directory_name_#{child_directory.id}\">"
        res += "<span class=\"directory-name-label\">"\
               "<a href=\"" + directory_path(child_directory) + "\">#{child_directory.name}</a>"\
                                                                "</span>"
        res += "</span>"
        res += "</div>"
      end
    end
    # Si le directory a des graphs, on lance le listage des graphs
    res += graphs_list(directory) if directory.graphs.count.positive?
    # Si le directory a des documents, on lance le listage des documents
    res += documents_list(directory) if directory.documents.count.positive?
    res += "</ol>" if directory_has_children?(directory)

    res += "</li>"
    res
  end
  # rubocop:enable Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

  def graphs_list(directory)
    res = ""
    Graph.ordered_for_ihm(directory.graphs).each do |graph|
      res += "<li data-snap-ignore=\"true\" data-type=\"graph\" data-id=\"#{graph.id}\" "\
             "data-title=\"#{graph.title}\" class=\"dd-item dd3-item "
      res += " current_item " if !@graph.nil? && @graph.id == graph.id
      res += "\">"
      res += "<div class=\"dd-handle dd3-handle\"></div>"
      res += "<div class=\"dd3-content\">"
      res += "<span class=\"graph-title\" id=\"graph_title_#{graph.id}\">"
      res += "<span class=\"graph-title-label\">"\
             "<a href=\"" + graph_path(graph) + "\" >[#{graph.type};#{graph.level}]#{graph.title}</a>"\
                                                "</span>"
      res += "</span>"
      res += "</div>"
      res += "</li>"
    end
    res
  end

  def documents_list(directory)
    res = ""
    directory.documents.each do |document|
      res += "<li data-snap-ignore=\"true\" data-type=\"document\" data-id=\"#{document.id}\" "\
             "data-title=\"#{document.title}\" class=\"dd-item dd3-item "
      res += " current_item " if !@document.nil? && @document.id == document.id
      res += "\">"
      res += "<div class=\"dd-handle dd3-handle\"></div>"
      res += "<div class=\"dd3-content\">"
      res += "<span class=\"document-title\" id=\"document_title_#{document.id}\">"
      res += "<span class=\"document-title-label\">"\
             "<a href=\"" +
             show_properties_document_path(document) +
             "\">"\
             "[DOC]#{document.title}.#{document.extension}</a></span>"
      res += "</span>"
      res += "</div>"
      res += "</li>"
    end
    res
  end
  # rubocop:enable Metrics/AbcSize

  def directory_has_children?(directory)
    directory.children.count.positive? || directory.graphs.count.positive? || directory.documents.count.positive?
  end
end
