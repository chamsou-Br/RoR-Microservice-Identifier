# frozen_string_literal: true

# == Schema Information
#
# Table name: external_users
#
#  id          :integer          not null, primary key
#  customer_id :integer
#  name        :string(255)
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_external_users_on_customer_id  (customer_id)
#

class ExternalUser < ApplicationRecord
  belongs_to :customer

  ### Audit Element for which the user is responsible
  has_many :audit_element_as_domain_responsible, as: :domain_responsible

  alias_attribute :display_name, :name

  validates :name, presence: true

  # These are very naive ways of calculating the first and last names.
  # At the moment, we just want the methods to exist and return something.
  #
  # This method returns the first string found in name.
  def firstname
    name.split(" ", 2).first
  end

  # This method returns the rest of the name that is not considered firstname.
  def lastname
    name.split(" ", 2).last
  end

  #
  # Returns a reduced JSON hash of this user including only the following
  # attributes: `id` and `name`, and methods: `firstname` and `lastname`.
  #
  # @return [Hash{String => String, Hash}]
  #
  def serialize_this
    as_json(only: %i[id name], methods: %i[firstname lastname])
  end
end
