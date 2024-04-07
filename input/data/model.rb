# frozen_string_literal: true

# == Schema Information
#
# Table name: models
#
#  id          :integer          not null, primary key
#  name        :string(255)
#  type        :string(255)
#  level       :integer
#  landscape   :boolean          default(FALSE)
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  customer_id :integer
#  tree        :boolean          default(FALSE)
#
# Indexes
#
#  index_models_on_customer_id  (customer_id)
#

# TODO: given that he name is very ambiguous, what is the role of this "Model"?
class Model < ApplicationRecord
  has_many :graphs
  belongs_to :customer

  self.inheritance_column = nil
  validates :name, presence: true
  validates :type, inclusion: { in: %w[process human environment] }
  validates :level, inclusion: { in: [1, 2, 3] }

  # TODO: Move `self.types` to class constant
  def self.types
    %w[process human environment]
  end
end
