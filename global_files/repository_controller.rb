# frozen_string_literal: true

class RepositoryController < ApplicationController
  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  def set_parent_directory
    directory_id = params[:directory_id] || params[:repository_content_id]
    item_type = params[:item_type]
    item_id = params[:item_id]
    repository_content_id = params[:repository_content_id]
    @root_directory = Directory.root
    @directory = Directory.find(repository_content_id) if !repository_content_id.nil? && !repository_content_id.empty?
    collapsed_dirs = params[:directories_collapsed]
    @directories_collapsed = collapsed_dirs[
      collapsed_dirs.index("\"") + 1..collapsed_dirs.rindex("\"") - 1
    ].split(";")
    directory = Directory.find(directory_id)

    case item_type
    when "graph"
      graph = Graph.find(item_id)
      directory.graphs << graph
    when "document"
      document = Document.find(item_id)
      directory.documents << document
    end

    @message_type = "success"
    @message = I18n.t("controllers.repository.successes.set_parent_directory")
    respond_to do |format|
      format.js {}
    end
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength
end
