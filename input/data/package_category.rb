# frozen_string_literal: true

# == Schema Information
#
# Table name: package_categories
#
#  id                         :integer          not null, primary key
#  package_id                 :integer
#  static_package_category_id :integer
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#

class PackageCategory < ApplicationRecord
  belongs_to :package
  belongs_to :static_package_category
end
