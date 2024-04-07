# frozen_string_literal: true

# == Schema Information
#
# Table name: imported_packages
#
#  id          :integer          not null, primary key
#  package_id  :integer
#  customer_id :integer
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#

class ImportedPackage < ApplicationRecord
  belongs_to :package
  belongs_to :customer

  has_many :graphs
  has_many :documents
  has_many :roles
end
