# frozen_string_literal: true

# == Schema Information
#
# Table name: entity_reviews
#
#  id          :integer          not null, primary key
#  entity_type :string(255)      not null
#  entity_id   :integer          not null
#  reviewer_id :integer          not null
#  approved    :boolean          not null
#  reviewed_at :datetime         not null
#  active      :boolean          not null
#  comment     :string(255)
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_entity_reviews_on_entity_type_and_entity_id  (entity_type,entity_id)
#  index_entity_reviews_on_reviewer_id                (reviewer_id)
#
# Foreign Keys
#
#  fk_rails_...  (reviewer_id => users.id)
#

class EntityReview < ApplicationRecord
  belongs_to :entity, polymorphic: true
  belongs_to :reviewer,
             class_name: "User",
             foreign_key: "reviewer_id",
             inverse_of: "entity_reviews"

  validates :approved, :active, inclusion: { in: [true, false] }
  validates :reviewed_at, presence: true

  validates :entity_type,
            inclusion: { in: %w[Risk Act Audit Event] }
end
