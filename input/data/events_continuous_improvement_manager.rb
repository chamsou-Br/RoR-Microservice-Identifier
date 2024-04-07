# frozen_string_literal: true

# == Schema Information
#
# Table name: events_continuous_improvement_managers
#
#  id                                :integer          not null, primary key
#  event_id                          :integer
#  continuous_improvement_manager_id :integer
#  created_at                        :datetime         not null
#  updated_at                        :datetime         not null
#  response                          :boolean
#  response_at                       :datetime
#  comment                           :string(255)
#

class EventsContinuousImprovementManager < ApplicationRecord
  # @!attribute [rw] continuous_improvement_manager
  #   @return [User]
  belongs_to :continuous_improvement_manager, class_name: "User"

  # @!attribute [rw] event
  #   @return [Event]
  belongs_to :event

  #
  # Full name of the CIM
  #
  # @return [String]
  # @deprecated Use the {#continuous_improvement_manager} to get the {User} and
  #   gets its full name using {User#name} and {User::Name#full}
  #
  def display_username
    continuous_improvement_manager.name.full
  end

  #
  # Initials of the CIM
  #
  # @return [String]
  # @deprecated Use the {#continuous_improvement_manager} to get the {User} and
  #   gets its initials using {User#name} and {User::Name#initials}
  #
  def display_username_initial
    continuous_improvement_manager.name.initials
  end
end
