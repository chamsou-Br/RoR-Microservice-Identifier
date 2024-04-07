# frozen_string_literal: true

# == Schema Information
#
# Table name: graph_backgrounds
#
#  id                   :integer          not null, primary key
#  file                 :string(255)
#  color                :string(255)
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  pattern              :string(255)
#  pattern_fill_color   :string(255)
#  pattern_stroke_color :string(255)
#  opacity              :integer          default(100)
#

class GraphBackground < ApplicationRecord
  mount_uploader :file, GraphBackgroundUploader

  has_one :graph

  validates :file, presence: true, if: proc { |b| b.color.blank? && b.pattern.blank? }
  validates :color, presence: true, if: proc { |b| b.pattern.blank? && b.file.blank? }
  validates :pattern,
            presence: true, if: proc { |b| b.color.blank? && b.file.blank? },
            format: { with: /\A^(circles-[1-6]|dots-[1-6]|diagonal-stripe-[1-6])\z/ }

  # TODO: Rename `set_type` to `type=` and refactor
  # rubocop:disable Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
  # rubocop:disable Naming/AccessorMethodName
  def set_type(graph_background_params)
    if graph_background_params["file"].present?
      update_attributes(
        color: nil,
        pattern: nil,
        opacity: graph_background_params["opacity"]
      )
    elsif graph_background_params["pattern"].present?
      remove_file! if file.present?
      update_attributes(
        pattern: graph_background_params["pattern"],
        pattern_fill_color: graph_background_params["pattern_fill_color"] || "#ffffff",
        pattern_stroke_color: graph_background_params["pattern_stroke_color"] || "#000000",
        file: nil,
        color: nil,
        opacity: graph_background_params["opacity"]
      )
    elsif graph_background_params["color"].present?
      remove_file! if file.present?
      update_attributes(
        color: graph_background_params["color"],
        file: nil,
        pattern: nil,
        opacity: graph_background_params["opacity"]
      )
    end
  end
  # rubocop:enable Naming/AccessorMethodName
  # rubocop:enable Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

  # TODO: Move `self.pattern_types` to class constant and update references
  def self.pattern_types
    %w[circles diagonal-stripe dots]
  end
end
