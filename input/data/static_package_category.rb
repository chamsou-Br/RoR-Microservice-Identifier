# frozen_string_literal: true

# == Schema Information
#
# Table name: static_package_categories
#
#  id         :integer          not null, primary key
#  name       :string(255)
#  family     :integer
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

class StaticPackageCategory < ApplicationRecord
  # Read only table, in the business logic, but nothing prevents additions.
  # This Validation prevents creating the same field twice.
  #
  validates :name, uniqueness: true
  enum family: { operation: 0, support: 1, management: 2 }

  def self.humanize_categories
    all.order(:name).map do |category|
      {
        id: category.id,
        name: I18n.t("activerecord.models.static_package_category.categories.#{category.name}")
      }
    end
  end

  def humanize_name
    I18n.t("activerecord.models.static_package_category.categories.#{name}")
  end

  def self.filter_hash
    res = StaticPackageCategory.all.group_by do |p|
      I18n.t("activerecord.models.static_package_category.family.#{p.family}")
    end

    res.each_pair do |key, values|
      res[key] = values.map do |category|
        { id: category.id, name: category.humanize_name }
      end
    end
    res
  end
end
