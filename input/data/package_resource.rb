# frozen_string_literal: true

# == Schema Information
#
# Table name: package_resources
#
#  id            :integer          not null, primary key
#  package_id    :integer
#  resource_id   :integer
#  title         :string(255)
#  url           :string(255)
#  resource_type :string(255)
#  purpose       :text(65535)
#  logo          :string(255)
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#

class PackageResource < ApplicationRecord
  belongs_to :package
  belongs_to :resource

  def self.create_from(resource, package)
    package_resource = PackageResource.new(
      resource.attributes.reject do |k, _|
        %w[id customer_id author_id deactivated imported_package_id].include?(k)
      end
    ) do |e|
      e.package = package
      e.resource = resource
    end
    package_resource.save
    package_resource
  end

  # TODO: Refactor `create_corresponding_resource` to use hash when creating
  # resource
  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  def create_corresponding_resource(target_user, imported_package, conflicts_to_solve)
    imported_resource = target_user.customer.resources.new(
      attributes.reject do |k, _|
        %w[created_at updated_at id package_id resource_id].include?(k)
      end
    ) do |r|
      r.imported_package_id = imported_package.id
      r.author = target_user
    end

    unless conflicts_to_solve.nil?
      imported_resource = apply_conflicts_resolution(imported_resource,
                                                     conflicts_to_solve)
    end

    if !imported_resource.nil? && !resource.logo.nil? &&
       !resource.logo.file.nil? && !resource.logo.file.file.nil?
      imported_resource.logo = File.open(resource.logo.file.file)
    end

    imported_resource.save if !imported_resource.nil? && imported_resource.errors.empty?

    imported_resource
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

  # TODO: Refactor `apply_conflicts_resolution` into external module since many
  # element classes seem to have this very familiar method
  # rubocop:disable Metrics/MethodLength
  def apply_conflicts_resolution(imported_resource, conflicts_to_solve)
    res = imported_resource
    conflicts_to_solve.each do |conflict_to_solve|
      if conflict_to_solve[:resolutionCode] == 1
        # do_not_import
        return nil
      end

      case conflict_to_solve[:type]
      when "SAME_TITLE"
        case conflict_to_solve[:resolutionCode]
        when 0
          # rename
          res.title = conflict_to_solve[:resolutionInput]
        when 3
          # overwrite
          # Dans ce cas particulier, on ne destroy pas le repositoryItem, en
          # effet, il peut être utilisé dans des graphs (et être indestructible)
          # Donc on update ses attributes
          repository_item_resource = imported_resource.customer.resources
                                                      .find(conflict_to_solve[:repositoryItemId])
          res = repository_item_resource
          res.assign_attributes(attributes.reject do |k, _|
            %w[created_at updated_at id package_id resource_id].include?(k)
          end)
          res.imported_package_id = imported_resource.imported_package_id
          res.author = imported_resource.author
          res.deactivated = false
          # logger.debug "--> updating by overwrite of resource(#{res.id} : #{res.inspect})"
        end
      end
    end
    res
  end
  # rubocop:enable Metrics/MethodLength
end
