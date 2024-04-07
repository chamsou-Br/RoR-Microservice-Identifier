# frozen_string_literal: true

# == Schema Information
#
# Table name: localisations
#
#  id          :integer          not null, primary key
#  label       :string(255)
#  customer_id :integer
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_localisations_on_customer_id  (customer_id)
#  index_localisations_on_label        (label)
#

class Localisation < ApplicationRecord
  belongs_to :customer
  include LinkableFieldable

  has_many :localisings, dependent: :destroy
  has_many :events, through: :localisings, source: :localisable, source_type: "Event"
  has_many :acts, through: :localisings, source: :localisable, source_type: "Act"
  validates :label, uniqueness: { scope: [:customer_id], case_sensitive: true }, on: :create

  scope :autocompleter, ->(query) { where("label like :q COLLATE utf8_bin", q: "%#{query}%").order("label ASC") }

  # This is the wrong way to overwrite this method.
  # There is also a serializer which make this redundant.
  # def as_json(_options = {})
  #   { id: id, text: label }
  # end

  # TODO: at the moment this is redundant with app/serializer/localisation_serializer
  # but with too much informations. Need to do a manual serialiazer as other
  # parts (ElasticSearch) count on the default as_json method, so it cannot be
  # overwritten.
  def serialize_this
    as_json(only: %i[id label])
  end
end
