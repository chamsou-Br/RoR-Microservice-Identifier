# frozen_string_literal: true

# == Schema Information
#
# Table name: acts_validators
#
#  id           :integer          not null, primary key
#  act_id       :integer
#  validator_id :integer
#  response     :integer
#  response_at  :datetime
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#

class ActsValidator < ApplicationRecord
  # @!attribute [rw] validator
  #   @return [User]
  belongs_to :validator, class_name: "User"

  # @!attribute [rw] act
  #   @return [Act]
  belongs_to :act

  enum response: { not_checked: 0, efficient: 1, not_efficient: 2 }

  #
  # Returns the validator's full name
  #
  # @return [String]
  # @deprecated Use the {#validator} directly and get its full name using
  #   {User#name} and {User::Name#full}.
  #
  def display_username
    validator.name.full
  end

  #
  # Returns the validator's name initials
  #
  # @return [String]
  # @deprecated Use the {#validator} directly and get its initials using
  #   {User#name} and {User::Name#initials}.
  #
  def display_username_initial
    validator.name.initials
  end
end
