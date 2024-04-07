# frozen_string_literal: true

# == Schema Information
#
# Table name: opportunities
#
#  id                 :bigint(8)        not null, primary key
#  customer_id        :integer
#  state              :integer
#  internal_reference :string(255)
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#
# Indexes
#
#  index_opportunities_on_customer_id  (customer_id)
#
# Foreign Keys
#
#  fk_rails_...  (customer_id => customers.id)
#
class Opportunity < ApplicationRecord
  include OpportunityStateMachine
  include IamEntitySetup
  include IamApiMethods

  belongs_to :customer, inverse_of: :opportunities

  validates :state, :internal_reference, presence: true
  validates :internal_reference, uniqueness: { scope: [:customer_id] }

  enum state: { under_analysis: 0,
                pending_approval: 1,
                completed: 2,
                closed: 3,
                pending_closure: 4 }

  # Defined in the Tracktable module, to mark actors that are updated for
  # timelogging and notifications.
  # TODO: they need to be defined when timetracking and logging are implemented
  # fully.
  #
  def mark_dirty_actor(actor); end
end
