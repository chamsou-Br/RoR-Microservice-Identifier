# frozen_string_literal: true

# == Schema Information
#
# Table name: package_connections
#
#  id          :integer          not null, primary key
#  package_id  :integer
#  customer_id :integer
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#

class PackageConnection < ApplicationRecord
  belongs_to :package
  belongs_to :customer

  # We need to update the package document after creation/deletion of a package
  # Connection
  after_commit on: %i[create destroy] do |connection|
    connection.package.__elasticsearch__.index_document
  end
end
