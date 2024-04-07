# frozen_string_literal: true

# == Schema Information
#
# Table name: reference_settings
#
#  id                  :integer          not null, primary key
#  customer_setting_id :integer
#  event_prefix        :string(255)
#  act_prefix          :string(255)
#  audit_prefix        :string(255)
#
# Indexes
#
#  index_reference_settings_on_customer_setting_id  (customer_setting_id)
#

class ReferenceSetting < ApplicationRecord
  belongs_to :customer_setting

  validates :event_prefix, presence: true, length: { maximum: 10 }
  validates :act_prefix, presence: true, length: { maximum: 10 }
  validates :audit_prefix, presence: true, length: { maximum: 10 }

  def not_set?
    event_prefix.nil? || act_prefix.nil? || audit_prefix.nil?
  end

  # TODO: Rename `is_reference_prefixed_for?` to `reference_prefixed_for?`
  # rubocop:disable Naming/PredicateName
  def is_reference_prefixed_for?(klass)
    case klass.to_s
    when "Event"
      !event_prefix.blank?
    when "Act"
      !act_prefix.blank?
    when "Audit"
      !audit_prefix.blank?
    end
  end
  # rubocop:enable Naming/PredicateName
end
