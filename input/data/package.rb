# frozen_string_literal: true

# == Schema Information
#
# Table name: packages
#
#  id              :integer          not null, primary key
#  name            :string(255)
#  description     :text(65535)
#  state           :integer
#  private         :boolean
#  customer_id     :integer
#  published_at    :datetime
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  author_id       :integer
#  grouppackage_id :integer
#  maingraphs_type :integer
#
# Indexes
#
#  index_packages_on_customer_id  (customer_id)
#
# Foreign Keys
#
#  fk_rails_...  (customer_id => customers.id)
#

# TODO: Simplify Package model into smaller, composed modules
class Package < ApplicationRecord
  include SearchablePackage

  # TODO: a way for setting default value for state, private on package creation

  # will paginate default per page
  self.per_page = 50

  belongs_to :customer, foreign_key: "customer_id", class_name: "Customer"
  belongs_to :author, foreign_key: "author_id", class_name: "User"
  has_many :package_connections, dependent: :destroy
  has_many :connections, through: :package_connections, source: :customer
  has_many :package_categories, dependent: :destroy
  has_many :categories, through: :package_categories, source: :static_package_category
  belongs_to :grouppackage

  has_many :package_graphs, dependent: :destroy
  has_many :package_roles, dependent: :destroy
  has_many :package_resources, dependent: :destroy
  has_many :package_documents, dependent: :destroy

  has_many :imported_packages, dependent: :destroy
  has_many :imported_package_customers, through: :imported_packages, source: :customer

  has_many :taggings, as: :taggable, dependent: :destroy
  has_many :tags, through: :taggings, source: :tag

  enum state: { draft: 0, published: 1, deactivated: 2, archived: 3 }
  enum maingraphs_type: { applicable: 0, latest: 1 }

  validates :customer, presence: true

  def imported_at
    return nil if imported_packages.empty?

    imported_packages.last.created_at
  end

  def relinks_elements
    package_graphs.each(&:relinks_elements)
  end

  def clear
    %w[graphs roles documents connections categories resources].each do |relation_name|
      send("package_#{relation_name}").destroy_all
    end
  end

  # TODO: Shorten `inject_graph`
  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  def inject_graph(graph)
    package_graph = package_graphs.new
    package_graph.graph = graph
    package_graph.title = graph.title
    package_graph.type = graph.type
    package_graph.level = graph.level
    package_graph.state = graph.state
    package_graph.reference = graph.reference
    package_graph.domain = graph.domain
    package_graph.version = graph.version
    package_graph.purpose = graph.purpose
    package_graph.comment_index_int = graph.comment_index_int
    package_graph.news = graph.news
    package_graph.groupgraph_id = graph.groupgraph_id
    package_graph.confidential = graph.confidential
    package_graph.tree = graph.tree
    package_graph.print_footer = graph.print_footer

    if package_graph.save
      # inject elements
      graph.elements.each do |element|
        package_element = package_graph.elements.new
        package_element.element = element

        package_element.type = element.type

        # Attention : en face on a potentiellement un Groupgraph et non pas un
        # Graph, pareil pour Groupdocument...
        package_element.model_id = element.model_id
        package_element.x = element.x
        package_element.y = element.y
        package_element.width = element.width
        package_element.height = element.height
        package_element.text = element.text
        package_element.created_at = element.created_at
        package_element.updated_at = element.updated_at
        package_element.shape = element.shape
        package_element.parent_role = element.parent_role
        package_element.parent_id = element.parent_id
        package_element.comment = element.comment
        package_element.leasher_id = element.leasher_id
        package_element.font_size = element.font_size
        package_element.color = element.color
        package_element.indicator = element.indicator
        package_element.zindex = element.zindex
        package_element.titlePosition = element.titlePosition
        package_element.bold = element.bold
        package_element.italic = element.italic
        package_element.underline = element.underline
        package_element.corner_radius = element.corner_radius
        package_element.title_color = element.title_color
        package_element.title_fontfamily = element.title_fontfamily
        package_element.model_type = element.model_type
        package_element.logo = element.logo
        package_element.main_process = element.main_process
        package_element.raw_comment = element.raw_comment
        package_element.comment_color = element.comment_color

        package_element.save
      end
    end

    nil
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

  # TODO: Rename `importSelection` to `import_selection`
  # rubocop:disable Naming/MethodName
  def importSelection(target_customer)
    res = []

    # Graphs
    res += importGraphsSelection(target_customer)

    # Documents
    res += importDocumentsSelection(target_customer)

    # Roles
    res += importRolesSelection(target_customer)

    # Resources
    res += importResourcesSelection(target_customer)

    res
  end
  # rubocop:enable Naming/MethodName

  # TODO: This method is far to long and needs to be refactored
  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
  # rubocop:disable Naming/MethodName
  def importGraphsSelection(target_customer)
    res = []
    package_graphs.each do |package_graph|
      # Un graph déjà importé n'est plus à réimporter story #137688003
      conflicts = []
      already_imported_graph = target_customer.graphs.find_by(imported_uid: package_graph.graph_uid)
      if already_imported_graph.nil?
        # title conflict
        repository_graph_title_conflict = target_customer.graphs.where(title: package_graph.title).last
        # reference conflict
        repository_graph_reference_conflict = target_customer.graphs.where(reference: package_graph.reference).last
        if !repository_graph_title_conflict.nil? && !repository_graph_reference_conflict.nil?
          if repository_graph_title_conflict.id == repository_graph_reference_conflict.id
            conflict_type = "SAME_TITLE_AND_REFERENCE_WITH_ONE"
            conflicts << {
              type: conflict_type,
              resolutionOptions: graph_resolution_options(package_graph, conflict_type, repository_graph_title_conflict)
            }.merge(
              GraphSerializer.new(repository_graph_title_conflict, {})
              .to_hash
              .transform_keys { |key| "repositoryItem#{key.to_s.camelize}".to_sym }
            )
          else
            # Double conflits sur des items différents
            conflict_type = "SAME_TITLE_AND_REFERENCE_WITH_TWO"
            conflicts << {
              type: conflict_type,
              secondRepositoryItemId: repository_graph_reference_conflict.id,
              secondRepositoryItemTitle: repository_graph_reference_conflict.title,
              secondRepositoryItemReference: repository_graph_reference_conflict.reference,
              secondRepositoryItemLevel: repository_graph_reference_conflict.level,
              resolutionOptions: graph_resolution_options(package_graph, conflict_type, repository_graph_title_conflict,
                                                          repository_graph_reference_conflict)
            }.merge(
              GraphSerializer.new(repository_graph_reference_conflict, {})
              .to_hash
              .transform_keys { |key| "repositoryItem#{key.to_s.camelize}".to_sym }
            )
          end
        elsif !repository_graph_title_conflict.nil?
          conflict_type = "SAME_TITLE"
          conflicts << {
            type: conflict_type,
            resolutionOptions: graph_resolution_options(package_graph, conflict_type, repository_graph_title_conflict)
          }.merge(
            GraphSerializer.new(repository_graph_title_conflict, {})
            .to_hash
            .transform_keys { |key| "repositoryItem#{key.to_s.camelize}".to_sym }
          )
        elsif !repository_graph_reference_conflict.nil?
          conflict_type = "SAME_REFERENCE"
          conflicts << {
            type: conflict_type,
            resolutionOptions: graph_resolution_options(package_graph, conflict_type,
                                                        repository_graph_reference_conflict)
          }.merge(
            GraphSerializer.new(repository_graph_reference_conflict, {})
            .to_hash
            .transform_keys { |key| "repositoryItem#{key.to_s.camelize}".to_sym }
          )
        end
      else
        conflict_type = "ALREADY_IMPORTED"
        conflicts << {
          type: conflict_type,
          repositoryItemId: already_imported_graph.id,
          repositoryItemTitle: already_imported_graph.title,
          repositoryItemReference: already_imported_graph.reference,
          repositoryItemLevel: already_imported_graph.level,
          resolutionOptions: graph_resolution_options(package_graph, conflict_type, already_imported_graph)
        }
      end

      res << {
        type: "Graph",
        conflicts: conflicts
      }.merge(PackageGraphSerializer.new(package_graph, {}).to_hash)
    end

    res
  end
  # rubocop:enable Naming/MethodName
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

  # TODO: This method is far to long and needs to be refactored
  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
  # rubocop:disable Naming/MethodName
  def importDocumentsSelection(target_customer)
    res = []
    package_documents.each do |package_document|
      # Un document déjà importé n'est plus à réimporter story #137688003
      conflicts = []
      already_imported_document = target_customer.documents.find_by(imported_uid: package_document.document_uid)
      if already_imported_document.nil?
        # title conflict
        repository_document_title_conflict = target_customer.documents.where(title: package_document.title).last

        # reference conflict
        repository_document_reference_conflict = target_customer.documents
                                                                .where(reference: package_document.reference).last
        if !repository_document_title_conflict.nil? && !repository_document_reference_conflict.nil?
          if repository_document_title_conflict.id == repository_document_reference_conflict.id
            conflict_type = "SAME_TITLE_AND_REFERENCE_WITH_ONE"
            conflicts << {
              type: conflict_type,
              resolutionOptions: document_resolution_options(conflict_type, repository_document_title_conflict)
            }.merge(
              DocumentSerializer.new(repository_document_title_conflict, {})
              .to_hash
              .transform_keys { |key| "repositoryItem#{key.to_s.camelize}".to_sym }
            )
          else
            # Double conflits sur des items différents
            conflict_type = "SAME_TITLE_AND_REFERENCE_WITH_TWO"
            conflicts << {
              type: conflict_type,
              resolutionOptions: document_resolution_options(conflict_type, repository_document_title_conflict,
                                                             repository_document_reference_conflict),
              secondRepositoryItemId: repository_document_reference_conflict.id,
              secondRepositoryItemTitle: repository_document_reference_conflict.title,
              secondRepositoryItemReference: repository_document_reference_conflict.reference
            }.merge(
              DocumentSerializer.new(repository_document_reference_conflict, {})
              .to_hash
              .transform_keys { |key| "repositoryItem#{key.to_s.camelize}".to_sym }
            )
          end
        elsif !repository_document_title_conflict.nil?
          conflict_type = "SAME_TITLE"
          conflicts << {
            type: conflict_type,
            resolutionOptions: document_resolution_options(conflict_type, repository_document_title_conflict)
          }.merge(
            DocumentSerializer.new(repository_document_title_conflict, {})
            .to_hash
            .transform_keys { |key| "repositoryItem#{key.to_s.camelize}".to_sym }
          )
        elsif !repository_document_reference_conflict.nil?
          conflict_type = "SAME_REFERENCE"
          conflicts << {
            type: conflict_type,
            resolutionOptions: document_resolution_options(conflict_type, repository_document_reference_conflict)
          }.merge(
            DocumentSerializer.new(repository_document_reference_conflict, {})
            .to_hash
            .transform_keys { |key| "repositoryItem#{key.to_s.camelize}".to_sym }
          )
        end
      else
        conflict_type = "ALREADY_IMPORTED"
        conflicts << {
          type: conflict_type,
          resolutionOptions: document_resolution_options(conflict_type, already_imported_document)
        }.merge(
          DocumentSerializer.new(already_imported_document, {})
            .to_hash
            .transform_keys { |key| "repositoryItem#{key.to_s.camelize}".to_sym }
        )
      end

      res << {
        type: "Document",
        conflicts: conflicts
      }.merge(PackageDocumentSerializer.new(package_document, {}).to_hash)
    end

    res
  end
  # rubocop:enable Naming/MethodName
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

  # TODO: Rename `importRolesSelection` to `import_roles_selection`
  # rubocop:disable Metrics/MethodLength, Naming/MethodName
  def importRolesSelection(target_customer)
    res = []
    package_roles.each do |package_role|
      conflicts = []
      # title conflict
      repository_role_title_conflict = target_customer.roles.where("title LIKE BINARY ? ", package_role.title).last
      unless repository_role_title_conflict.nil?
        conflict_type = "SAME_TITLE"
        conflicts << {
          type: conflict_type,
          resolutionOptions: role_resolution_options(conflict_type, repository_role_title_conflict, package_role)
        }.merge(
          RoleSerializer.new(repository_role_title_conflict, {})
            .to_hash
            .transform_keys { |key| "repositoryItem#{key.to_s.camelize}".to_sym }
        )
      end
      res << {
        type: "Role",
        conflicts: conflicts
      }.merge(PackageRoleSerializer.new(package_role, {}).to_hash)
    end

    res
  end
  # rubocop:enable Metrics/MethodLength, Naming/MethodName

  # TODO: Rename `importResourcesSelection` to `import_resources_selection`
  # rubocop:disable Metrics/MethodLength, Naming/MethodName
  def importResourcesSelection(target_customer)
    res = []
    package_resources.each do |package_resource|
      conflicts = []
      # title conflict
      repository_resource_title_conflict = target_customer.resources.where(title: package_resource.title).last
      unless repository_resource_title_conflict.nil?
        conflict_type = "SAME_TITLE"
        conflicts << {
          type: conflict_type,
          resolutionOptions: resource_resolution_options(conflict_type, repository_resource_title_conflict)
        }.merge(
          ResourceSerializer.new(repository_resource_title_conflict, {})
            .to_hash
            .transform_keys { |key| "repositoryItem#{key.to_s.camelize}".to_sym }
        )
      end

      res << {
        type: "Resource",
        conflicts: conflicts
      }.merge(PackageResourceSerializer.new(package_resource, {}).to_hash)
    end

    res
  end
  # rubocop:enable Metrics/MethodLength, Naming/MethodName

  def imported_graphs
    package_graphs.map do |package_graph|
      {
        type: "Graph",
        id: package_graph.id,
        title: package_graph.title,
        level: package_graph.level,
        main: package_graph.main,
        reference: package_graph.reference
      }
    end
  end

  def imported_documents
    package_documents.map do |document|
      {
        type: "Document",
        id: document.id,
        title: document.title,
        reference: document.reference
      }
    end
  end

  def imported_roles
    package_roles.map do |role|
      {
        type: "Role",
        id: role.id,
        title: role.title
      }
    end
  end

  def imported_resources
    package_resources.map do |resource|
      {
        type: "Resource",
        id: resource.id,
        title: resource.title
      }
    end
  end

  # TODO: This method requires some refactoring
  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
  def graph_resolution_options(package_graph, conflict_type, repository_item, second_repository_item = nil)
    # When there is 2 items in conflict, repository_item is the one with the
    # title_conflct and second_repository_item is the one with the
    # reference_conflict

    res = [
      # option do_not_import est présente dans tous les cas.
      { key: :do_not_import, code: 1 }
    ]

    return res if conflict_type == "ALREADY_IMPORTED"

    # Gestion du cas particulier où le graph a déjà été importé

    # option rename est présente dans tous les autres cas. mais en fonction du conflict_type, çà veut dire :
    # SAME_TITLE --> rename_title
    # SAME_REFERENCE --> rename_reference
    # SAME_TITLE_AND_REFERENCE_WITH_ONE && SAME_TITLE_AND_REFERENCE_WITH_TWO --> rename les 2.
    res << { key: :rename, code: 0, input: true }

    # On empêche les transmutations de level...
    if repository_item.groupgraph.level == package_graph.level && repository_item.groupgraph.tree == package_graph.tree
      case conflict_type
      when "SAME_TITLE", "SAME_REFERENCE", "SAME_TITLE_AND_REFERENCE_WITH_ONE"
        case repository_item.groupgraph.last_available.state
        when "applicable", "deactivated"
          res << { key: :new_version, code: 2 }
        when "new"
          res << { key: :overwrite, code: 3 }
        end
      when "SAME_TITLE_AND_REFERENCE_WITH_TWO"
        case repository_item.groupgraph.last_available.state
        when "applicable", "deactivated"
          res << { key: :new_version_of_repository_item_renaming_reference, code: 4, input: true }
        when "new"
          res << { key: :overwrite_of_repository_item_renaming_reference, code: 5, input: true }
        end
        if second_repository_item.groupgraph.last_available.state == "applicable" ||
           repository_item.groupgraph.last_available.state == "deactivated"
          res << { key: :new_version_of_second_repository_item_renaming_title, code: 6, input: true }
        elsif second_repository_item.groupgraph.last_available.state == "new"
          res << { key: :overwrite_of_second_repository_item_renaming_title, code: 7, input: true }
        end
      end
    end

    res
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

  # TODO: This method requires some refactoring
  # rubocop:disable Metrics/CyclomaticComplexity, Metrics/MethodLength
  def document_resolution_options(conflict_type, repository_item, second_repository_item = nil)
    # When there is 2 items in conflict, repository_item is the one with the
    # title_conflct and second_repository_item is the one with the
    # reference_conflict
    res = [
      # option do_not_import est présente dans tous les cas
      { key: :do_not_import, code: 1 }
    ]

    return res if conflict_type == "ALREADY_IMPORTED"

    # Gestion du cas particulier où le document a déjà été importé

    # option rename est présente dans tous les cas. mais en fonction du conflict_type, çà veut dire :
    # SAME_TITLE --> rename_title
    # SAME_REFERENCE --> rename_reference
    # SAME_TITLE_AND_REFERENCE_WITH_ONE && SAME_TITLE_AND_REFERENCE_WITH_TWO --> rename les 2.
    res << { key: :rename, code: 0, input: true }

    case conflict_type
    when "SAME_TITLE", "SAME_REFERENCE", "SAME_TITLE_AND_REFERENCE_WITH_ONE"
      case repository_item.groupdocument.last_available.state
      when "applicable"
        res << { key: :new_version, code: 2 }
      when "new"
        res << { key: :overwrite, code: 3 }
      end
    when "SAME_TITLE_AND_REFERENCE_WITH_TWO"
      case repository_item.groupdocument.last_available.state
      when "applicable"
        res << { key: :new_version_of_repository_item_renaming_reference, code: 4, input: true }
      when "new"
        res << { key: :overwrite_of_repository_item_renaming_reference, code: 5, input: true }
      end
      case second_repository_item.groupdocument.last_available.state
      when "applicable"
        res << { key: :new_version_of_second_repository_item_renaming_title, code: 6, input: true }
      when "new"
        res << { key: :overwrite_of_second_repository_item_renaming_title, code: 7, input: true }
      end
    end

    res
  end
  # rubocop:enable Metrics/CyclomaticComplexity, Metrics/MethodLength

  def role_resolution_options(_conflict_type, repository_item, package_item)
    res = [
      # option rename
      { key: :rename, code: 0, input: true },

      # option do_not_import
      { key: :do_not_import, code: 1 }
    ]

    # option overwrite.
    # Attention : si les type de rôles sont différents, on ne doit pas permettre l'overwrite
    # En effet, le role est potentiellement utilisé dans des graphs, dans ce cas il ne peut être destroy puis remplacé.
    # Donc on update ses attributs mais il ne faudrait pas qu'il change de type au passage...
    res << { key: :overwrite, code: 3 } if repository_item.type == package_item.type

    res
  end

  # TODO: Remove these method parameters if they are never used
  def resource_resolution_options(_conflict_type, _repository_item)
    [
      # option rename
      { key: :rename, code: 0, input: true },

      # option do_not_import
      { key: :do_not_import, code: 1 },

      # option overwrite
      { key: :overwrite, code: 3 }
    ]
  end

  # TODO: This method is enormous and requires some serious refactoring...
  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
  def relink_imported_items(ids_mapping, imported_graphs, target_user)
    # contient les elements dont un id a été mappé. Ceci afin d'éviter de le
    # nullify en fin de méthode...
    imported_element_ids_mapped = []

    ids_mapping.each do |id_mapping|
      # logger.debug "--> --> relinking #{id_mapping} ... "
      case id_mapping[:type]
      when "Graph"
        # On récupère le groupgraph source
        groupgraph_src_id = package_graphs.find(id_mapping[:old_id]).groupgraph_id
        # On liste les éléments qui référence ce groupgraph
        imported_graphs.each do |imported_graph|
          imported_graph.elements
                        .where(model_type: "Groupgraph", model_id: groupgraph_src_id)
                        .each do |imported_element|
            if id_mapping[:new_id].nil?
              # logger.debug "--> nullifying model_id and model_type of
              # imported_element(#{imported_element.id}) : #{imported_element.text} ..."
              imported_element.update_attributes(model_type: nil, model_id: nil,
                                                 title_color: "rgb(0,0,0)", italic: false)
            else
              # On récupère le groupgraph cible
              groupgraph_target_id = id_mapping[:new_groupgraph_id]
              # logger.debug "--> setting model_id of imported_element(#{imported_element.id})
              # : #{imported_element.text} from #{imported_element.model_id} to #{groupgraph_target_id}..."
              imported_element.update_attributes(model_id: groupgraph_target_id)
            end
            imported_element_ids_mapped << imported_element
          end
        end
      when "Document"
        # On récupère le groupdocument source
        groupdocument_src_id = package_documents.find(id_mapping[:old_id]).groupdocument_id
        # On liste les éléments qui référence ce groupdocument
        imported_graphs.each do |imported_graph|
          imported_graph.elements
                        .where(model_type: "Groupdocument", model_id: groupdocument_src_id)
                        .each do |imported_element|
            if id_mapping[:new_id].nil?
              # logger.debug "--> nullifying model_id and model_type of
              # imported_element(#{imported_element.id}) : #{imported_element.text} ..."
              imported_element.update_attributes(model_type: nil, model_id: nil,
                                                 title_color: "rgb(0,0,0)", italic: false)
            else
              # On récupère le groupdocument cible
              groupdocument_target_id = id_mapping[:new_groupdocument_id]
              # logger.debug "--> setting model_id of imported_element(#{imported_element.id})
              # : #{imported_element.text} from #{imported_element.model_id} to #{groupdocument_target_id}..."
              imported_element.update_attributes(model_id: groupdocument_target_id)
            end
            imported_element_ids_mapped << imported_element
          end
        end
      when "Resource"
        # On récupère le role source
        resource_src_id = package_resources.find(id_mapping[:old_id]).resource_id
        # On liste les éléments qui référence ce resource
        imported_graphs.each do |imported_graph|
          imported_graph.elements.where(model_type: "Resource", model_id: resource_src_id).each do |imported_element|
            if id_mapping[:new_id].nil?
              # logger.debug "--> nullifying model_id and
              # model_type of imported_element(#{imported_element.id}) : #{imported_element.text} ..."
              imported_element.update_attributes(model_type: nil, model_id: nil,
                                                 title_color: "rgb(0,0,0)", italic: false)
            else
              # logger.debug "--> setting model_id of imported_element(#{imported_element.id})
              # : #{imported_element.text} from #{imported_element.model_id} to #{id_mapping[:new_id]}..."
              imported_element.update_attributes(model_id: id_mapping[:new_id])
            end
            imported_element_ids_mapped << imported_element
          end
        end

      end
    end
    # Il reste a linker les elements de type role au entities roles du target_customer
    # Pour les autres, il faut nullifier le lien (car le related element n'est pas dans le package...)
    imported_graphs.each do |imported_graph|
      imported_graph.elements.each do |imported_element|
        role_linked = false
        if imported_element.model_type == "Role" && !imported_element.model_id.nil?
          # Etape 1 : S'il est du package, on le link (et çà gère le cas du role
          #           imported and renamed...)
          # Etape 2 : Sinon si role de même title+type trouvé, on le link
          # Etape 3 : Sinon on TRY le create+link (peut ne pas fonctionner car
          #           same_title de type différent dans le repository...)
          # Etape 4 : Sinon unlink.
          # Etape 5 : on rajoute le role dans les graph.roles << role

          # Etape 1 :
          package_role = package_roles.find_by(role_id: imported_element.model_id)
          unless package_role.nil?
            # logger.debug "--> --> --> package_role founded : #{package_role.id}
            # with role_id : #{package_role.role_id}"
            ids_mapping.each do |id_mapping|
              # logger.debug "--> --> scanning id_mapping : #{id_mapping} ..."
              unless id_mapping[:type] == "Role" && id_mapping[:old_id] == package_role.id &&
                     !id_mapping[:new_id].nil?
                next
              end

              # logger.debug "-> detected that #{id_mapping[:type]} == Role
              # and id_mapping[:old_id] match package_role.id(#{package_role.id})"
              # logger.debug "--> Etape 1 for imported_element(#{imported_element.id})
              # : #{imported_element.text} --> link it to #{id_mapping[:new_id]}"
              imported_element.update_attributes(model_id: id_mapping[:new_id])
              imported_element_ids_mapped << imported_element
              role_linked = true
              break
            end
          end
        end

        if !role_linked && imported_element.shape == "role" || imported_element.shape == "relatedRole"
          # Etape 2
          if !role_linked && !imported_graph.customer.roles.find_by(title: imported_element.text,
                                                                    type: imported_element.type).nil?
            target_role_id = imported_graph.customer.roles.find_by(title: imported_element.text,
                                                                   type: imported_element.type).id
            imported_element.update_attributes(model_id: target_role_id, model_type: "Role")
            imported_element_ids_mapped << imported_element
            # logger.debug "--> Etape 2 for imported_element(#{imported_element.id}) : #{imported_element.text}"
            role_linked = true
          end
          # Etape 3
          unless role_linked
            new_role = target_user.customer.roles.new(title: imported_element.text, type: imported_element.type,
                                                      author: target_user, writer: target_user,
                                                      imported_package_id: id)
            if new_role.save
              # link
              imported_element.update_attributes(model_id: new_role.id, model_type: "Role")
              imported_element_ids_mapped << imported_element
              # logger.debug "--> Etape 3 for imported_element(#{imported_element.id}) : #{imported_element.text}"
              role_linked = true
            else
              # Etape 4 : unlink
              imported_element.update_attributes(model_id: nil, model_type: nil, title_color: "rgb(0,0,0)",
                                                 italic: false)
              imported_element_ids_mapped << imported_element
              # logger.debug "--> Etape 4 for imported_element(#{imported_element.id}) : #{imported_element.text}"
            end
          end
        end

        # Etape 5
        if role_linked
          final_role = target_user.customer.roles.find(imported_element.model_id)
          imported_graph.roles << final_role
        end

        # Enfin, on nullify les élément qui ont encore des id n'ayant pas été mappés.
        unless imported_element_ids_mapped.include?(imported_element)
          imported_element.update_attributes(model_id: nil, model_type: nil, title_color: "rgb(0,0,0)", italic: false)
        end
      end
    end
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  def duplicate
    transaction do
      package = dup
      package.state = 0
      package.save
      package_connections.each do |connection|
        new_connection = connection.dup
        new_connection.package = package
        new_connection.save
      end
      package_categories.each do |category|
        new_category = category.dup
        new_category.package = package
        new_category.save
      end
      package_roles.each do |role|
        new_role = role.dup
        new_role.package = package
        new_role.save
      end
      package_resources.each do |resource|
        new_resource = resource.dup
        new_resource.package = package
        new_resource.save
      end
      package_documents.each do |document|
        new_document = document.dup
        new_document.package = package
        new_document.save
      end
      package_graphs.each do |package_graph|
        PackageGraph.create_from_graph(package, package_graph.graph, package_graph.main)
      end
      package.relinks_elements

      # TODO: Test removing `return` keyword as Rails docs state `transaction`
      # returns the value of the block it is given, thus `package`
      # https://api.rubyonrails.org/classes/ActiveRecord/ConnectionAdapters/DatabaseStatements.html#method-i-transaction
      return package
    end
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength
end
