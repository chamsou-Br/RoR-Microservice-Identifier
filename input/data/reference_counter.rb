# frozen_string_literal: true

# == Schema Information
#
# Table name: reference_counters
#
#  id          :integer          not null, primary key
#  event       :integer          default(0)
#  act         :integer          default(0)
#  customer_id :integer
#  audit       :integer          default(0)
#  risk        :integer          default(0), not null
#
# Indexes
#
#  index_reference_customer_action  (customer_id,act) UNIQUE
#  index_reference_customer_audit   (customer_id,audit) UNIQUE
#  index_reference_customer_event   (customer_id,event) UNIQUE
#

class ReferenceCounter < ApplicationRecord
  belongs_to :customer

  # TODO: Use `%<>s` syntax for format string tokens
  def formated_event_counter
    "#{customer.settings.reference_setting.event_prefix}#{format('%06d', event)}"
  end

  def formated_act_counter
    "#{customer.settings.reference_setting.act_prefix}#{format('%06d', act)}"
  end

  def formated_audit_counter
    "#{customer.settings.reference_setting.audit_prefix}#{format('%06d', audit)}"
  end

  # TODO: ok, one of those spelling mistakes that expand over some surface area
  # def formatted_risk_counter
  # TODO: find the correct format.
  # rubocop:disable Style/FormatString
  def formated_risk_counter
    "RSK%06d" % risk
  end
  # rubocop:enable Style/FormatString
end
