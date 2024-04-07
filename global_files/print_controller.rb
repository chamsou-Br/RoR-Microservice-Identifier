# frozen_string_literal: true

class PrintController < ApplicationController
  include ListableWorkflow

  after_action :verify_authorized, except: %i[preferences print]

  def preferences
    @graph = params[:graph_ids]
    @document = params[:document_ids]

    definition = list_index_definition.merge(class: "graph")
    @has_graph = (!list_selection(definition).nil? || !@graph.blank?)

    @list_selection = lambda do
      if !@graph.blank?
        "graph,#{@graph}:graph"
      elsif !@document.blank?
        "document,#{@document}:document"
      end
    end
  end

  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
  def print
    graph_list = list_selection(list_index_definition.merge(class: "graph"))
    document_list = list_selection(list_index_definition.merge(class: "document"))

    @graphs = []
    @documents = []
    @preferences_lexicon = params[:lexicon] == "yes"
    @preferences_comments = params[:comments] == "yes"
    @preferences_properties = params[:properties] == "yes"
    @preferences_interactions = params[:interactions] == "yes"
    @preferences_actors = params[:actors] == "yes"
    @preferences_diary = params[:diary] == "yes"
    @preferences_versions_list = params[:versions_list] == "yes"

    print_properties_condition = @preferences_lexicon || @preferences_comments || @preferences_properties ||
                                 @preferences_interactions || @preferences_actors || @preferences_diary ||
                                 @preferences_versions_list

    graph_list&.each do |graph|
      authorize graph, :graph_viewable?
      @graphs << graph
    end

    document_list&.each do |document|
      authorize document, :document_viewable?
      @documents << document
    end

    respond_to do |format|
      format.html { render layout: "print" }
      format.pdf do
        combined_pdf = CombinePDF.new

        assigns = { preferences_lexicon: @preferences_lexicon,
                    preferences_comments: @preferences_comments,
                    preferences_properties: @preferences_properties,
                    preferences_interactions: @preferences_interactions,
                    preferences_actors: @preferences_actors,
                    preferences_diary: @preferences_diary,
                    preferences_versions_list: @preferences_versions_list }

        graph_renderer = ::PrintRenderer::GraphPdfRenderer.new(
          user: current_user, session_id: session.id, assigns: assigns
        )

        @graphs.each do |graph|
          pdf = graph_renderer.render_pdf(graph, "graph.html.erb", graph.level == 1 ? "landscape" : "portrait")
          combined_pdf << CombinePDF.parse(pdf)
          if print_properties_condition
            pdf = graph_renderer.render_pdf(graph, "graph_properties.html.erb")
            combined_pdf << CombinePDF.parse(pdf)
          end
        end
        document_renderer = ::PrintRenderer::DocumentPdfRenderer.new(assigns)
        @documents.each do |document|
          pdf = document_renderer.render_pdf(document, "document.html.erb")
          combined_pdf << CombinePDF.parse(pdf)
        end

        filename = build_filename(@graphs, @documents)
        combined_pdf.number_pages(location: :bottom_right,
                                  margin_from_height: 15,
                                  number_format: "%s/#{combined_pdf.pages.count}")

        send_data(combined_pdf.to_pdf, filename: filename,
                                       type: "application/pdf",
                                       disposition: "inline")
        return
      end
    end
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

  private

  #
  # Returns a file name depending on the graphs and documents provided.  If both
  # `graphs` and `documents` parameters are empty, raises `ArgumentError`
  #
  # @param [Array<Graph>] graphs
  # @param [Array<Document>] documents
  #
  # @return [String]
  #
  def build_filename(graphs, documents)
    prefix = if graphs.length > 1 || documents.length > 1 || graphs.length == 1 && documents.length == 1
               "multiprint"
             elsif graphs.length == 1
               "#{I18n.t('activerecord.models.graph.one')}_#{graphs[0].title}".parameterize.underscore
             elsif documents.length == 1
               "#{I18n.t('activerecord.models.document.one')}_#{documents[0].title}".parameterize.underscore
             else
               raise ArgumentError, "Must provide at least 1 graph or document"
             end

    "#{prefix}_#{Time.now.strftime('%Y%m%d_%H%M')}.pdf"
  end
end
