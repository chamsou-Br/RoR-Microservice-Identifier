# frozen_string_literal: true

class DirectoriesController < ApplicationController
  include Listable
  include SearchHelper

  before_action :set_root_directory
  rename_with :name

  def index
    @user = current_user
    unless current_customer.freemium? && !current_customer.internal? && !@user.skip_homepage
      redirect_to(dashboard_index_path) and return flash.keep
    end

    render layout: "freemium"
  end

  def new
    @directory = Directory.new(parent_id: @root_directory.id)
  end

  def create
    directory_name = params[:directory][:name]
    parent_directory = current_customer.directories.find(params[:directory][:parent_id])
    @directory = Directory.new(customer: current_customer,
                               name: directory_name,
                               parent_id: parent_directory.id,
                               author: current_user)

    begin
      authorize @directory, :create?
    rescue StandardError
      @directory.errors.add :base, :create_not_allowed
    end

    if @directory.errors.empty? && @directory.save
      flash_x_success I18n.t("controllers.directory.successes.create")
    else
      fill_errors_hash(I18n.t("controllers.directory.errors.create"), @directory)
    end
  end

  def edit; end

  def confirm_delete; end

  # TODO: Break down into smaller private methods
  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
  def delete_directories
    logger.debug "--> params : #{params}"
    @directory = current_customer.directories.find(params[:parent_id])
    directories = list_selection(list_show_definition.merge(class: "directory"))
    count = directories ? directories.count : 1
    error_occured = directories.nil?
    archived_graphs = []
    archived_documents = []
    unless error_occured
      directories.each do |directory|
        begin
          authorize directory, :destroy?
        rescue StandardError
          error_occured = true
          directory.errors.add :base, :delete_directories_not_allowed
        end
        archived_graphs = directory.archived_child_graphs
        archived_documents = directory.archived_child_documents

        if directory.destroy
          current_customer.graphs.where(id: archived_graphs.map(&:id))
                          .update_all(directory_id: current_customer.root_directory.id)
          current_customer.documents.where(id: archived_documents.map(&:id))
                          .update_all(directory_id: current_customer.root_directory.id)
          flash_x_success I18n.t("controllers.directory.successes.delete_directories", count: count)
        else
          flash_x_error directory.errors[:base].first
        end
      end
    end

    respond_to do |format|
      format.js {}
    end
  end

  # TODO: One can also move a graph from the graph page, through the
  # move_graph method. There should not be 2 ways to do the same thing.
  #
  # TODO: Simplify this method with smaller private methods
  def move_directories
    @directory = current_customer.directories.find(params[:current_directory_id]) if params[:current_directory_id] != ""

    error_occured = false
    parent_id = params[:parent_id]
    begin
      parent_directory = current_customer.directories.find(parent_id)
    rescue StandardError
      fill_errors_hash I18n.t("controllers.directory.errors.move_directories.no_target_dir"), @directory
      error_occured = true
    end

    # TODO: Un-nest this transaction to use normal unless block
    # rubocop:disable Style/MultilineIfModifier
    Directory.transaction do
      list_definition = list_show_definition

      unless error_occured
        directories = list_selection(list_definition.merge(class: "directory"))
        directories&.each do |directory|
          if parent_id == directory.id
            fill_errors_hash(I18n.t("controllers.directory.errors.move_directories.recursive"), directory)
            error_occured = true
          elsif parent_directory.self_and_ancestors.include?(directory)
            # On vérifie qu'il n'y a pas d'inclusion dans la descendance
            fill_errors_hash(I18n.t("controllers.directory.errors.move_directories.recursive_ancestor"), directory)
            error_occured = true
          else
            # TODO: Move exception handling out
            # rubocop:disable Metrics/BlockNesting
            begin
              authorize directory, :move_directory?
            rescue StandardError
              fill_errors_hash(
                I18n.t("controllers.directory.errors.move_directories.not_allowed", name: directory.name),
                directory
              )
              error_occured = true
            end
            # rubocop:enable Metrics/BlockNesting
            parent_directory.children << directory
          end
        end
      end

      # Déplacement des graphs
      unless error_occured
        graphs = list_selection(list_definition.merge(class: "graph"))
        graphs&.each do |graph|
          begin
            authorize graph, :move_graph?
          rescue StandardError
            fill_errors_hash(
              I18n.t("controllers.directory.errors.move_directories.not_graph_author", title: graph.title),
              graph
            )
            error_occured = true
          end

          graph.directory = parent_directory
          next if graph.save

          fill_errors_hash(
            I18n.t("controllers.directory.errors.move_directories.graph_not_saved", title: graph.title),
            graph
          )
          error_occured = true
        end
      end

      # Déplacement des documents
      unless error_occured
        documents = list_selection(list_definition.merge(class: "document"))
        documents&.each do |document|
          begin
            authorize document, :action_document?
          rescue StandardError
            fill_errors_hash(
              I18n.t("controllers.directory.errors.move_directories.not_document_author", title: document.title),
              document
            )
            error_occured = true
          end

          document.directory = parent_directory
          next if document.save

          fill_errors_hash(
            I18n.t("controllers.directory.errors.move_directories.document_not_saved", title: document.title),
            document
          )
          error_occured = true
        end
      end

      if error_occured
        logger.debug "ActiveRecord::Rollback engaged !"
        raise ActiveRecord::Rollback
      end
    end unless error_occured
    # rubocop:enable Style/MultilineIfModifier

    if error_occured
      flash_x_error ActionController::Base.helpers.strip_tags modal_errors(@errors)
    else
      respond_to do |format|
        format.html { flash[:success] = I18n.t("controllers.directory.successes.move_directories") }
        format.js { flash_x_success I18n.t("controllers.directory.successes.move_directories") }
      end
    end
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

  def show
    @directory = @root_directory.self_and_descendants.find(params[:id])
    respond_to do |format|
      format.html {}
      format.json do
        render_list("show", :list_show_definition, favor: true,
                                                   properties: true,
                                                   tags: true,
                                                   graphes: true,
                                                   documents: true,
                                                   likers: true , 
                                                   author: true)
      end
    end
  end

  def confirm_move; end

  private

  def set_root_directory
    @root_directory = current_customer.root_directory
  end

  # TODO: Refactor out into model scope or class methods
  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  def list_show_definition
    {
      items: lambda do
        directory_contents = policy(@directory).contents
        directory_contents.directories + directory_contents.graphs + directory_contents.documents
      end,
      search: lambda do |_children, term|
        tree_view_search(term, @directory, current_user, size: 10_000).records.to_a
      end,
      tabs: {
        all: ->(children) { children },
        favored: lambda do |children|
          children.select do |child|
            current_user.directories_favored.include?(child) ||
              current_user.graphs_favored.include?(child) ||
              current_user.documents_favored.include?(child)
          end
        end
      },
      orders: {
        type: ->(children) { order_children_by_type(children) },
        created: ->(children) { order_children_by_created_at(children) },
        updated: ->(children) { order_children_by_updated_at(children) },
        title: ->(children) { order_children_by_title(children) },
        title_inv: ->(children) { order_children_by_title_inv(children) }
      },
      post: lambda do |children|
        parent = @directory.parent_id.nil? ? [] : [@directory.parent]
        parent + children
      end
    }
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

  def order_children_by_type(children)
    directories = order_children_by_title(children.select { |child| child.is_a?(Directory) })
    graphs = order_children_by_title(children.select { |child| child.is_a?(Graph) })
    documents = order_children_by_title(children.select { |child| child.is_a?(Document) })
    directories + graphs + documents
  end

  def order_children_by_title(children)
    children.sort do |child_1, child_2|
      title_1 = child_1.is_a?(Directory) ? child_1.name : child_1.title
      title_2 = child_2.is_a?(Directory) ? child_2.name : child_2.title
      title_1 <=> title_2
    end
  end

  def order_children_by_title_inv(children)
    children.sort do |child_1, child_2|
      title_1 = child_1.is_a?(Directory) ? child_1.name : child_1.title
      title_2 = child_2.is_a?(Directory) ? child_2.name : child_2.title
      title_2 <=> title_1
    end
  end

  def order_children_by_created_at(children)
    groups = {}
    children
      .sort { |child_1, child_2| child_2.created_at <=> child_1.created_at }
      .each { |child| (groups[child.created_at] ||= []) << child }
    groups
      .map { |_date, group| order_children_by_title(group) }
      .flatten
      .flatten
      .reject { |item| item.is_a?(ActiveSupport::TimeWithZone) }
  end

  def order_children_by_updated_at(children)
    groups = {}
    children
      .sort { |child_1, child_2| child_2.updated_at <=> child_1.updated_at }
      .each { |child| (groups[child.updated_at] ||= []) << child }
    groups
      .map { |_date, group| order_children_by_title(group) }
      .flatten
      .flatten
      .reject { |item| item.is_a?(ActiveSupport::TimeWithZone) }
  end
end
