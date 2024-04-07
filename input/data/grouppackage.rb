# frozen_string_literal: true

# == Schema Information
#
# Table name: grouppackages
#
#  id          :integer          not null, primary key
#  customer_id :integer
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#

class Grouppackage < ApplicationRecord
  has_many :packages, dependent: :destroy
  belongs_to :customer

  def last_available
    packages.last
  end

  def published_version
    packages.where(state: Package.states["published"]).last
  end
end
