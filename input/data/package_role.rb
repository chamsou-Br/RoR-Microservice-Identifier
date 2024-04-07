# frozen_string_literal: true

# == Schema Information
#
# Table name: package_roles
#
#  id         :integer          not null, primary key
#  package_id :integer
#  role_id    :integer
#  title      :string(255)
#  type       :string(255)
#  mission    :string(2300)
#  activities :string(2300)
#  purpose    :string(2300)
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

class PackageRole < ApplicationRecord
  belongs_to :package
  belongs_to :role

  self.inheritance_column = nil

  def self.create_from(role, package)
    package_role = PackageRole.new(
      role.attributes.reject do |k, _|
        %w[id author_id writer_id customer_id deactivated imported_package_id].include?(k)
      end
    ) do |e|
      e.package = package
      e.role = role
    end
    package_role.save

    package_role
  end

  def create_corresponding_role(target_user, imported_package, conflicts_to_solve)
    imported_role = target_user.customer.roles.new(
      attributes.reject do |k, _|
        %w[created_at updated_at id package_id role_id].include?(k)
      end
    ) do |r|
      r.imported_package_id = imported_package.id
      r.author = target_user
      r.writer = target_user
    end

    unless conflicts_to_solve.nil?
      imported_role = apply_conflicts_resolution(imported_role,
                                                 conflicts_to_solve)
    end

    imported_role.save if !imported_role.nil? && imported_role.errors.empty?

    imported_role
  end

  # TODO: Refactor `apply_conflicts_resolution` to use smaller private methods
  # rubocop:disable Metrics/MethodLength
  def apply_conflicts_resolution(imported_role, conflicts_to_solve)
    res = imported_role
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
          # Dans ce cas particulier, on ne destroy pas le repositoryItem, en effet, il peut être utilisé dans des graphs
          # (et être indestructible)
          # Donc on update ses attributes
          # Attention : on exclut le type pour éviter le changement de type de role... normalement, dans ce cas de
          # figure, l'overwrite ne devrait pas être proposé.
          repository_item_role = imported_role.customer.roles.find(conflict_to_solve[:repositoryItemId])
          res = repository_item_role
          res.assign_attributes(attributes.reject do |k, _|
            %w[created_at updated_at id package_id role_id type].include?(k)
          end)
          res.imported_package_id = imported_role.imported_package_id
          res.author = imported_role.author
          res.writer = imported_role.writer
          res.deactivated = false
          # logger.debug "--> updating by overwrite of role(#{res.id} : #{res.inspect})"
        end
      end
    end

    res
  end
  # rubocop:enable Metrics/MethodLength
end
