# frozen_string_literal: true

# == Schema Information
#
# Table name: pastilles
#
#  id                  :integer          not null, primary key
#  element_id          :integer
#  role_id             :integer
#  pastille_setting_id :integer
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#
# Indexes
#
#  index_pastilles_on_element_id           (element_id)
#  index_pastilles_on_pastille_setting_id  (pastille_setting_id)
#

class Pastille < ApplicationRecord
  belongs_to :element
  belongs_to :pastille_setting

  validates :element, presence: true
  validates :role_id, presence: true

  def self.create_or_update_from_json(js_pastille)
    logger.debug("pastille.create_or_update_from_json")
    if js_pastille["id"].is_a?(Numeric)
      pastille = find_or_create_by(id: js_pastille["id"])
      pastille.update_attributes(
        "element_id" => js_pastille["element_id"],
        "role_id" => js_pastille["role_id"],
        "pastille_setting_id" => js_pastille["pastille_setting_id"].to_i
      )
    else
      logger.debug "create the pastille from js_pastille : #{js_pastille}"
      js_pastille.delete_if { |key, _value| key == "id" }
      pastille = create do |a|
        a.element_id = js_pastille["element_id"]
        a.role_id = js_pastille["role_id"]
        a.pastille_setting_id = js_pastille["pastille_setting_id"].to_i
      end
    end

    pastille
  end
end
