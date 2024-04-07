# frozen_string_literal: true

# == Schema Information
#
# Table name: field_items
#
#  id            :integer          not null, primary key
#  form_field_id :integer
#  sequence      :integer          not null
#  label         :string(255)
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  integer_value :integer
#  color         :string(255)
#  activated     :boolean          default(TRUE), not null
#  i18n_key      :string(255)
#  parent_id     :integer
#
# Indexes
#
#  index_field_items_on_form_field_id                             (form_field_id)
#  index_field_items_on_sequence_and_form_field_id_and_parent_id  (sequence,form_field_id,parent_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (form_field_id => form_fields.id)
#

# The class holds items belonging to a select field, both custom and predefined.
# It manages a position on a given item scoped by form_field and parent.
class FieldItem < ApplicationRecord
  # global
  acts_as_list column: :sequence,
               scope: %i[form_field_id parent_id],
               top_of_list: 0

  # relations
  #
  belongs_to :form_field

  # NOTE: although it would not make any sense to leave field_values from a
  # deleted field_item, field_items cannot be deleted if they have
  # field_values. To perform the test in `:presence_field_values`, the option
  # `dependent: :destroy` has to be removed. This callback is called before
  # `:before_destroy`.
  #
  has_many :field_values, as: :entity

  belongs_to :parent, class_name: "FieldItem", optional: true
  has_many :children, class_name: "FieldItem",
                      foreign_key: :parent_id,
                      dependent: :destroy
  accepts_nested_attributes_for :children
  before_destroy :presence_field_values

  #
  # Returns all the descendants of the current field_item in a flat array.
  # When there are not children, returns empty array.
  #
  # @return [Array<FieldItem>]
  #
  def descendants
    children | children.map(&:descendants).flatten
  end

  #
  # The method is used to validate the non-presence of field_values for the
  # deletion of the field_value to proceed.
  #
  # @raise [ArgumentError] when the field_item or any of its descendants has
  # field_values. The raised error halts execution, which seems to be the only
  # way to prevent the deletion under a condition. As such, the error must be
  # rescued in the graphql mutation. It appears that Rails does not have
  # "validation on deletion", and throwing an error is the option presented:
  # https://stackoverflow.com/questions/123078/how-do-i-validate-on-destroy-in-rails
  # https://makandracards.com/makandra/20301-cancelling-the-activerecord-callback-chain
  #
  def presence_field_values
    ([self] + descendants).each do |fi|
      next unless fi.field_values.any?

      message = "Field item #{fi.id} has field values. "\
                "It and any members of its family cannot be deleted."
      errors.add(:base, message)
      raise ArgumentError, message
    end
  end

  def serialize_this
    as_json(
      only: %i[id form_field_id sequence label value color parent_id activated]
    )
  end
end
