# frozen_string_literal: true

# == Schema Information
#
# Table name: responses
#
#  id                  :bigint(8)        not null, primary key
#  response            :integer          default("abstained")
#  response_at         :datetime
#  active              :boolean          default(TRUE)
#  entity_type         :string(255)
#  entity_id           :bigint(8)
#  user_id             :integer
#  full_responsibility :string(255)
#  comment             :string(255)
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#
# Indexes
#
#  index_responses_on_entity_type_and_entity_id  (entity_type,entity_id)
#
class Response < ApplicationRecord
  belongs_to :entity, polymorphic: true
  belongs_to :user

  before_save :set_response_at

  enum response: { abstained: 0,
                   approved: 1,
                   refused: 2,
                   viewed: 3,
                   validated: 4 }

  ENTITIES = %w[Act Audit Event Opportunity Risk].freeze
  validates :entity_type, inclusion: { in: ENTITIES }

  # There should be only one active response per user, per responsibility.
  validates :active,
            uniqueness: {
              scope: %i[user_id entity full_responsibility],
              # TODO: to be replaced by a string translator.
              message: "There should only be one active response in this scope."
            },
            if: :active?

  def set_response_at
    self.response_at ||= Time.current
  end
end
