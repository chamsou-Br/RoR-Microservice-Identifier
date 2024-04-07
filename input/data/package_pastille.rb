# frozen_string_literal: true

# == Schema Information
#
# Table name: package_pastilles
#
#  id         :integer          not null, primary key
#  element_id :integer
#  role_id    :integer
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  label      :string(255)
#

class PackagePastille < ApplicationRecord
  belongs_to :package_element, foreign_key: "element_id"

  def self.create_from(pastille)
    package_pastille = PackagePastille.new(
      pastille.attributes.reject do |k, _|
        %w[id pastille_setting_id].include?(k)
      end
    ) do |e|
      e.label = pastille.pastille_setting.label
    end
    package_pastille.save
    package_pastille
  end

  def self.create_pastille_from(package_pastille, graph)
    pastille = Pastille.new(
      package_pastille.attributes.reject do |k, _|
        %w[created_at updated_at id label].include?(k)
      end
    ) do |e|
      possible_pastille_settings = graph.customer.settings.pastilles
                                        .where(label: package_pastille.label)
      pastille_setting = if possible_pastille_settings.empty?
                           graph.customer.settings.pastilles.where(label: "1").first
                         else
                           possible_pastille_settings.first
                         end
      e.pastille_setting = pastille_setting
    end
    pastille.save
    pastille
  end
end
