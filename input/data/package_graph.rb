# frozen_string_literal: true

# == Schema Information
#
# Table name: package_graphs
#
#  id                :integer          not null, primary key
#  package_id        :integer
#  graph_id          :integer
#  graph_uid         :string(255)
#  groupgraph_id     :integer
#  groupgraph_uid    :string(255)
#  main              :boolean          default(FALSE)
#  title             :string(255)
#  type              :string(255)
#  level             :integer
#  state             :string(255)
#  reference         :string(255)
#  domain            :text(65535)
#  version           :string(255)
#  purpose           :string(12000)
#  comment_index_int :boolean          default(TRUE)
#  news              :string(765)
#  confidential      :boolean          default(FALSE)
#  tree              :boolean          default(FALSE)
#  print_footer      :string(100)
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
class PackageGraph < ApplicationRecord
  belongs_to :package
  belongs_to :graph

  has_many :elements, -> { order "zindex asc" }, dependent: :destroy, class_name: "PackageElement"
  has_many :arrows, dependent: :destroy, class_name: "PackageArrow"
  has_many :lanes, dependent: :destroy, class_name: "PackageLane"

  self.inheritance_column = nil

  # TODO: Refactor `self.create_from_graph`
  def self.create_from_graph(package, graph, main = true)
    package_graph = PackageGraph.new(
      graph.attributes.reject do |key, _|
        %w[id author_id parent_id read_confirm_reminds_at graph_background_id
           model_id directory_id customer_id svg pilot_id imported_package_id
           uid imported_uid imported_groupgraph_uid].include?(key)
      end
    ) do |p|
      p.package = package
      p.graph = graph
      p.main = main
      p.graph_uid = graph.uid
      p.groupgraph_uid = graph.groupgraph.uid
    end

    package_graph.save
    PackageElement.copy_elements_from_to(graph, package_graph)

    package_graph
  end

  # TODO: Refactor into 4 smaller private methods
  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  def relinks_elements
    # unlink resources not included in package
    elements.where(model_type: "Resource").each do |element|
      unless package.package_resources.exists?(resource_id: element.model_id)
        element.update_attributes(model_type: nil, model_id: nil)
      end
    end

    # unlink roles not included in package
    elements.where(model_type: "Role").each do |element|
      unless package.package_roles.exists?(role_id: element.model_id)
        element.update_attributes(model_type: nil, model_id: nil)
      end
    end

    # unlink graphs not included in package
    elements.where(model_type: "Groupgraph").each do |element|
      unless package.package_graphs.exists?(groupgraph_id: element.model_id)
        element.update_attributes(model_type: nil, model_id: nil)
      end
    end

    # unlink documents not included in package
    elements.where(model_type: "Groupdocument").each do |element|
      unless package.package_documents.exists?(groupdocument_id: element.model_id)
        element.update_attributes(model_type: nil, model_id: nil)
      end
    end
  end

  # TODO: Refactor `create_corresponding_graph` into smaller method or use hash
  # to create new graph
  # rubocop:disable Metrics/MethodLength
  def create_corresponding_graph(target_user, imported_package, conflicts_to_solve)
    imported_graph = target_user.customer.graphs.new(
      attributes.reject do |key, _|
        %w[created_at updated_at id package_id graph_id groupgraph_id main state
           graph_uid groupgraph_uid].include?(key)
      end
    ) do |g|
      g.author = target_user
      g.state = Graph.states.first
      g.directory = target_user.customer.root_directory
      g.imported_package_id = imported_package.id
      g.imported_uid = graph_uid
      g.imported_groupgraph_uid = groupgraph_uid
    end

    imported_graph = apply_conflicts_resolution(imported_graph, conflicts_to_solve) unless conflicts_to_solve.nil?

    # graph_background
    if !graph.nil? && !imported_graph.nil? && imported_graph.errors.empty? && !graph.background.nil?
      imported_graph_background = graph.background.dup

      if !graph.background.file.nil? && !graph.background.file.file.nil? && !graph.background.file.file.file.nil?
        imported_graph_background.file = File.open(graph.background.file.file.file)
      end

      if imported_graph_background.save
        imported_graph.background = imported_graph_background
      else
        logger.debug "error on saving imported_graph_background : #{imported_graph_background.errors.messages}"
      end
    end

    if !imported_graph.nil? && imported_graph.errors.empty? && imported_graph.save
      PackageElement.copy_package_elements_from_to(self, imported_graph)
      GraphsLog.create(graph_id: imported_graph.id, user_id: imported_graph.author_id,
                       action: "imported", comment: nil)
    end

    imported_graph
  end

  # TODO: Refactor `apply_conflicts_resolution`
  # This method is very complex and should really be broken down into smaller
  # private methods with much more code reuse.
  # rubocop:disable Naming/VariableName
  def apply_conflicts_resolution(imported_graph, conflicts_to_solve)
    res = imported_graph
    conflicts_to_solve.each do |conflict_to_solve|
      if conflict_to_solve[:resolutionCode] == 1
        # do_not_import
        return nil
      end

      case conflict_to_solve[:type]
      when "SAME_TITLE", "SAME_REFERENCE", "SAME_TITLE_AND_REFERENCE_WITH_ONE"
        case conflict_to_solve[:resolutionCode]
        when 0
          # rename
          case conflict_to_solve[:type]
          when "SAME_TITLE"
            res.title = conflict_to_solve[:resolutionInput]
          when "SAME_REFERENCE"
            res.reference = conflict_to_solve[:resolutionInput]
          when "SAME_TITLE_AND_REFERENCE_WITH_ONE"
            res.title = conflict_to_solve[:resolutionTitleInput]
            res.reference = conflict_to_solve[:resolutionReferenceInput]
          end
        when 2
          # new version
          repositoryItem_groupgraph = imported_graph.customer.graphs
                                                    .find(conflict_to_solve[:repositoryItemId])
                                                    .groupgraph
          if repositoryItem_groupgraph.last_available.state == "applicable" ||
             repositoryItem_groupgraph.last_available.state == "deactivated"
            res.parent_id = repositoryItem_groupgraph.last_available.id
            res.version = find_available_version(repositoryItem_groupgraph)
            res.groupgraph = repositoryItem_groupgraph
          else
            res.errors.add :base, :impossible_to_create_new_version
          end
        when 3
          # overwrite
          repositoryItem_groupgraph = imported_graph.customer.graphs
                                                    .find(conflict_to_solve[:repositoryItemId])
                                                    .groupgraph
          if repositoryItem_groupgraph.last_available.state == "new"
            # Destruction de repositoryItem
            res.parent_id = repositoryItem_groupgraph.last_available.parent_id
            res.version = repositoryItem_groupgraph.last_available.version
            repositoryItem_groupgraph.last_available.destroy
            res.groupgraph = repositoryItem_groupgraph
          else
            res.errors.add :base, :impossible_to_overwrite_new_version
          end
        end
      when "SAME_TITLE_AND_REFERENCE_WITH_TWO"
        case conflict_to_solve[:resolutionCode]
        when 4
          # new_version_of_repository_item_renaming_reference
          repositoryItem_groupgraph = imported_graph.customer.graphs
                                                    .find(conflict_to_solve[:repositoryItemId])
                                                    .groupgraph
          if repositoryItem_groupgraph.last_available.state == "applicable" ||
             repositoryItem_groupgraph.last_available.state == "deactivated"
            res.parent_id = repositoryItem_groupgraph.last_available.id
            res.version = find_available_version(repositoryItem_groupgraph)
            res.groupgraph = repositoryItem_groupgraph
            res.reference = conflict_to_solve[:resolutionReferenceInput]
          else
            res.errors.add :base, :impossible_to_create_new_version
          end
        when 5
          # overwrite_of_repository_item_renaming_reference
          repositoryItem_groupgraph = imported_graph.customer.graphs
                                                    .find(conflict_to_solve[:repositoryItemId])
                                                    .groupgraph
          if repositoryItem_groupgraph.last_available.state == "new"
            # Destruction de repositoryItem
            res.parent_id = repositoryItem_groupgraph.last_available.parent_id
            res.version = repositoryItem_groupgraph.last_available.version
            repositoryItem_groupgraph.last_available.destroy
            res.groupgraph = repositoryItem_groupgraph
            res.reference = conflict_to_solve[:resolutionReferenceInput]
          else
            res.errors.add :base, :impossible_to_overwrite_new_version
          end
        when 6
          # new_version_of_second_repository_item_renaming_title
          repositoryItem_groupgraph = imported_graph.customer.graphs
                                                    .find(conflict_to_solve[:secondRepositoryItemId])
                                                    .groupgraph
          if repositoryItem_groupgraph.last_available.state == "applicable" ||
             repositoryItem_groupgraph.last_available.state == "deactivated"
            res.parent_id = repositoryItem_groupgraph.last_available.id
            res.version = find_available_version(repositoryItem_groupgraph)
            res.groupgraph = repositoryItem_groupgraph
            res.title = conflict_to_solve[:resolutionTitleInput]
          else
            res.errors.add :base, :impossible_to_create_new_version
          end
        when 7
          # overwrite_of_second_repository_item_renaming_title
          repositoryItem_groupgraph = imported_graph.customer.graphs
                                                    .find(conflict_to_solve[:secondRepositoryItemId])
                                                    .groupgraph
          if repositoryItem_groupgraph.last_available.state == "new"
            # Destruction de repositoryItem
            res.parent_id = repositoryItem_groupgraph.last_available.parent_id
            res.version = repositoryItem_groupgraph.last_available.version
            repositoryItem_groupgraph.last_available.destroy
            res.groupgraph = repositoryItem_groupgraph
            res.reference = conflict_to_solve[:resolutionReferenceInput]
          else
            res.errors.add :base, :impossible_to_overwrite_new_version
          end
        end
      end
    end

    res
  end
  # rubocop:enable Naming/VariableName
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

  def find_available_version(groupgraph)
    used_versions = groupgraph.graphs.pluck(:version)
    99.times do |i|
      return i.to_s unless used_versions.include?(i.to_s)
    end
  end
end
