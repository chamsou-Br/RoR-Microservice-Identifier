# frozen_string_literal: true

# == Schema Information
#
# Table name: localisings
#
#  id               :integer          not null, primary key
#  localisable_id   :integer
#  localisable_type :string(255)
#  localisation_id  :integer
#
# Indexes
#
#  index_localisings_on_localisable_id_and_localisable_type  (localisable_id,localisable_type)
#  index_localisings_on_localisation_id                      (localisation_id)
#

class Localising < ApplicationRecord
  belongs_to :localisable, polymorphic: true
  belongs_to :localisation
  accepts_nested_attributes_for :localisation

  before_save do |local|
    local.localisation.update(customer_id: local.localisable.customer_id)
  end
end
