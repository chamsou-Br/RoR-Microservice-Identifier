# frozen_string_literal: true

# == Schema Information
#
# Table name: package_documents
#
#  id                :integer          not null, primary key
#  package_id        :integer
#  document_id       :integer
#  document_uid      :string(255)
#  groupdocument_id  :integer
#  groupdocument_uid :string(255)
#  title             :string(255)
#  url               :string(2083)
#  reference         :string(255)
#  version           :string(255)
#  extension         :string(255)
#  file              :string(255)
#  purpose           :string(12000)
#  domain            :text(65535)
#  confidential      :boolean          default(FALSE)
#  news              :string(765)
#  print_footer      :string(100)
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#

# TODO: Refactor `PackageDocument` into smaller class by externalizing method
class PackageDocument < ApplicationRecord
  belongs_to :package
  belongs_to :document

  self.inheritance_column = nil

  def self.create_from(document, package)
    package_document = PackageDocument.new(
      document.attributes.reject do |k, _|
        %w[id directory_id customer_id author_id parent_id pilot_id
           read_confirm_reminds_at state imported_package_id uid imported_uid
           imported_groupdocument_uid].include?(k)
      end
    ) do |e|
      e.package = package
      e.document = document
      e.document_uid = document.uid
      e.groupdocument_uid = document.groupdocument.uid
    end
    package_document.save
    package_document
  end

  # TODO: Refactor `create_corresponding_document` to use hash for doc creation
  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
  def create_corresponding_document(target_user, imported_package, conflicts_to_solve)
    imported_document = target_user.customer.documents.new(attributes.reject do |k, _|
      %w[created_at updated_at id package_id document_id groupdocument_id
         document_uid groupdocument_uid].include?(k)
    end) do |d|
      d.author = target_user
      d.state = Document.states.first
      d.directory = target_user.customer.root_directory
      d.imported_package_id = imported_package.id
      d.imported_uid = document_uid
      d.imported_groupdocument_uid = groupdocument_uid
    end
    # logger.debug "--> source document of package_document #{self.id} is : " \
    # "#{document.id}, his file is : #{document.file}"
    # logger.debug "--> copy of file of the document..."
    if !document.file.nil? && !document.file.file.nil? && !document.file.file.file.nil?
      imported_document.file = File.open(document.file.file.file)
    end

    # logger.debug "--> now, imported_document is : #{imported_document.id}, " \
    # "his file is : #{imported_document.file}"
    unless conflicts_to_solve.nil?
      imported_document = apply_conflicts_resolution(imported_document,
                                                     conflicts_to_solve)
    end

    if !imported_document.nil? && imported_document.errors.empty? && imported_document.save
      DocumentsLog.create(document_id: imported_document.id,
                          user_id: imported_document.author_id,
                          action: "imported", comment: nil)
    end
    imported_document
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

  # TODO: Refactor `apply_conflicts_resolution` into external module to be included
  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
  # TODO: Rename local variables to use snake_case
  # rubocop:disable Naming/VariableName
  def apply_conflicts_resolution(imported_document, conflicts_to_solve)
    res = imported_document
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
          repositoryItem_groupdocument = imported_document.customer.documents
                                                          .find(conflict_to_solve[:repositoryItemId])
                                                          .groupdocument
          if repositoryItem_groupdocument.last_available.state == "applicable"
            res.parent_id = repositoryItem_groupdocument.last_available.id
            res.version = find_available_version(repositoryItem_groupdocument)
            res.groupdocument = repositoryItem_groupdocument
          else
            res.errors.add :base, :impossible_to_create_new_version
          end
        when 3
          # overwrite
          repositoryItem_groupdocument = imported_document.customer.documents
                                                          .find(conflict_to_solve[:repositoryItemId])
                                                          .groupdocument
          if repositoryItem_groupdocument.last_available.state == "new"
            # Destruction de repositoryItem
            res.parent_id = repositoryItem_groupdocument.last_available.parent_id
            res.version = repositoryItem_groupdocument.last_available.version
            repositoryItem_groupdocument.last_available.destroy
            res.groupdocument = repositoryItem_groupdocument
          else
            res.errors.add :base, :impossible_to_overwrite_new_version
          end
        end
      when "SAME_TITLE_AND_REFERENCE_WITH_TWO"
        case conflict_to_solve[:resolutionCode]
        when 4
          # new_version_of_repository_item_renaming_reference
          repositoryItem_groupdocument = imported_document.customer.documents
                                                          .find(conflict_to_solve[:repositoryItemId])
                                                          .groupdocument
          if repositoryItem_groupdocument.last_available.state == "applicable"
            res.parent_id = repositoryItem_groupdocument.last_available.id
            res.version = find_available_version(repositoryItem_groupdocument)
            res.groupdocument = repositoryItem_groupdocument
            res.reference = conflict_to_solve[:resolutionReferenceInput]
          else
            res.errors.add :base, :impossible_to_create_new_version
          end
        when 5
          # overwrite_of_repository_item_renaming_reference
          repositoryItem_groupdocument = imported_document.customer.documents
                                                          .find(conflict_to_solve[:repositoryItemId])
                                                          .groupdocument
          if repositoryItem_groupdocument.last_available.state == "new"
            # Destruction de repositoryItem
            res.parent_id = repositoryItem_groupdocument.last_available.parent_id
            res.version = repositoryItem_groupdocument.last_available.version
            repositoryItem_groupdocument.last_available.destroy
            res.groupdocument = repositoryItem_groupdocument
            res.reference = conflict_to_solve[:resolutionReferenceInput]
          else
            res.errors.add :base, :impossible_to_overwrite_new_version
          end
        when 6
          # new_version_of_second_repository_item_renaming_title
          repositoryItem_groupdocument = imported_document.customer.documents
                                                          .find(conflict_to_solve[:secondRepositoryItemId])
                                                          .groupdocument
          if repositoryItem_groupdocument.last_available.state == "applicable"
            res.parent_id = repositoryItem_groupdocument.last_available.id
            res.version = find_available_version(repositoryItem_groupdocument)
            res.groupdocument = repositoryItem_groupdocument
            res.title = conflict_to_solve[:resolutionTitleInput]
          else
            res.errors.add :base, :impossible_to_create_new_version
          end
        when 7
          # overwrite_of_second_repository_item_renaming_title
          repositoryItem_groupdocument = imported_document.customer.documents
                                                          .find(conflict_to_solve[:secondRepositoryItemId])
                                                          .groupdocument
          if repositoryItem_groupdocument.last_available.state == "new"
            # Destruction de repositoryItem
            res.parent_id = repositoryItem_groupdocument.last_available.parent_id
            res.version = repositoryItem_groupdocument.last_available.version
            repositoryItem_groupdocument.last_available.destroy
            res.groupdocument = repositoryItem_groupdocument
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

  def find_available_version(groupdocument)
    used_versions = groupdocument.documents.pluck(:version)
    99.times do |i|
      return i.to_s unless used_versions.include?(i.to_s)
    end
  end
end
