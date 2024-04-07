# frozen_string_literal: true

# == Schema Information
#
# Table name: colors
#
#  id                  :integer          not null, primary key
#  customer_setting_id :integer
#  value               :string(255)
#  default             :boolean          default(FALSE)
#  active              :boolean          default(FALSE)
#  position            :integer          not null
#

class Color < ApplicationRecord
  acts_as_list scope: :customer_setting_id

  belongs_to :customer_setting

  validates :value, presence: true

  scope :basic, -> { where(default: true, active: true, value: %w[ffffff 000000]) }
  scope :default, -> { where(default: true) }
  scope :custom, -> { where(default: false) }
  scope :active, -> { where(active: true) }

  before_destroy do |color|
    raise ActiveRecord::Rollback if color.default
  end

  validate :color_limit_reached
  validate :default_color_and_value_not_changed, on: :update

  # TODO: Move `self.white_hex` to class constant and change references to this method
  def self.white_hex
    "ffffff"
  end

  # TODO: Move `self.black_hex` to class constant and change references to this method
  def self.black_hex
    "000000"
  end

  # TODO: Move `self.colors_max_limit` to class constant and change references to this method
  def self.colors_max_limit
    6
  end

  def self.shades_palette(color_hex, options = {}, reverse = true)
    options = { type: :shades, from: :color, size: 7,
                color: Paleta::Color.new(:hex, color_hex) }.merge(options)
    palette = Paleta::Palette.generate(options)
    if reverse
      palette = Paleta::Palette.generate(options).reverse_each.map { |p| p }
      palette.delete_at(6)
    end
    palette
  end

  private

  def color_limit_reached
    return if customer_setting.colors.custom.count <= Color.colors_max_limit

    errors.add :base, I18n.t("activerecord.errors.color.base.limit_reached")
  end

  def default_color_and_value_not_changed
    return unless default_and_persisted?

    # Changed needed for Rails 5.2 upgrade. attr_changed? will have opposite
    # behavior. Leaving code commented as this is not tested.
    #
    # if value_changed?
    if will_save_change_to_value?
      errors.add(:value, I18n.t("activerecord.errors.color.value.default_changed"))
    # elsif position_changed?
    elsif will_save_change_to_position?
      errors.add(:position, I18n.t("activerecord.errors.color.position.default_changed"))
    end
  end

  def default_and_persisted?
    default && persisted?
  end
end
