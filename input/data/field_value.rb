# frozen_string_literal: true

# == Schema Information
#
# Table name: field_values
#
#  id             :integer          not null, primary key
#  fieldable_id   :integer
#  fieldable_type :string(255)
#  value          :text(65535)
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  form_field_id  :integer
#  entity_id      :integer
#  entity_type    :string(255)
#
# Indexes
#
#  form_field_links                     (form_field_id,entity_id,entity_type,fieldable_id,fieldable_type) UNIQUE
#  index_field_values_on_form_field_id  (form_field_id)
#

# The class is responsible for keeping values of all the fields
# belonging to a form of a given fieldable entity (ex. Risk)
#
class FieldValue < ApplicationRecord
  # associations
  belongs_to :entity, polymorphic: true, optional: true
  belongs_to :fieldable, polymorphic: true, touch: true
  belongs_to :form_field

  # validations
  validates :value, length: { maximum: 65_535 }

  validates :form_field_id,
            uniqueness: { scope: %i[entity_id entity_type fieldable_id
                                    fieldable_type] },
            if: -> { entity_id.present? && entity_type.present? }

  # custom validations
  validates_with FieldValueValidator

  scope :predef, -> { joins(:form_field).where("form_fields.custom = false") }

  # Query scope used to preload associated form fields, best used to avoid N+1
  scope :with_field_attributes, lambda { |form_field_attributes|
    includes(:form_field).joins(:form_field)
                         .where(form_fields: form_field_attributes)
  }

  # Query scope used to filter field values by their associated field names
  #
  # @see `with_field_attributes` scope
  scope :named, ->(*names) { with_field_attributes(field_name: names) }

  # nested attributes
  accepts_nested_attributes_for :entity, :form_field

  # These delegates should only be used when a field value's associated form
  # field is eager-loaded alongside the value to avoid N+1 queries
  #
  # @see `with_field_attributes` scope
  delegate :app_model, :custom, :editable, :field_name, :field_type,
           :form_section, :group, :required, :sequence, :version_id, :visible,
           to: :form_field

  def serialize_this
    as_json(only: %i[id fieldable_id fieldable_type entity_id entity_type value])
  end
end
