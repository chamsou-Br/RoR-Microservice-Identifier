# frozen_string_literal: true

require "sidekiq/api"
# == Schema Information
#
# Table name: reminders
#
#  id              :integer          not null, primary key
#  remindable_id   :integer
#  remindable_type :string(255)
#  job_id          :string(255)
#  reminder_type   :string(255)
#  occurs_at       :date
#  reminds_at      :date
#  from_id         :integer
#  to_id           :integer
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  index_reminders_on_from_id                            (from_id)
#  index_reminders_on_remindable_id_and_remindable_type  (remindable_id,remindable_type)
#  index_reminders_on_to_id                              (to_id)
#

class Reminder < ApplicationRecord
  attr_accessor :duration_type
  attr_reader :duration_value

  # @!attribute [rw] remindable
  #   @return [ApplicationRecord, nil]
  belongs_to :remindable, polymorphic: true

  # @!attribute [rw] from
  #   @return [User]
  # @!attribute [rw] from_id
  #   @return [Integer]
  belongs_to :from, foreign_key: "from_id", class_name: "User"

  # @!attribute [rw] to
  #   @return [User]
  # @!attribute [rw] to_id
  #   @return [Integer]
  belongs_to :to, foreign_key: "to_id", class_name: "User"

  validates :reminder_type, inclusion: { in: %w[act_estimated_start_at
                                                act_estimated_closed_at
                                                audit_estimated_start_at
                                                audit_estimated_closed_at
                                                graph_review_date] }
  validates :occurs_at, :reminds_at, :to_id, presence: true
  validates :from_id, presence: true, allow_nil: true
  validate :check_dates

  before_destroy do |reminder|
    Sidekiq::ScheduledSet.new.select { |job| job.delete if job.jid == reminder.job_id }
  end

  def duration_value=(str_value)
    return if /\A[+]?\d+\Z/.match(str_value).nil?

    value = str_value.to_i
    duration = case duration_type
               when "weeks"
                 value.weeks
               when "months"
                 value.months
               else
                 value.days
               end
    self.reminds_at = occurs_at - duration
  end

  def check_dates
    return if reminds_at.nil?

    errors.add(:reminds_at, :earlier_than_current_date) if Date.today > reminds_at
  end

  def perform
    jid = SendReminderWorker.perform_at(reminds_at.to_time.to_i, id)
    update_attribute("job_id", jid) unless jid.nil?
  end

  def remindable_url(helpers, host)
    return nil if remindable.nil?

    case remindable_type
    when "Act"
      helpers.improver_action_url(remindable, host)
    when "Groupgraph"
      helpers.graph_url(remindable.last_available, host)
    end
  end

  def remindable_path(helpers)
    return nil if remindable.nil?

    case remindable_type
    when "Act"
      helpers.improver_action_path(remindable)
    when "Audit"
      helpers.improver_audit_path(remindable)
    when "Groupgraph"
      helpers.graph_path(remindable.last_available)
    end
  end

  # TODO: Move `duration_types` instance method into class constant and replace
  # references
  def duration_types
    %w[days weeks months]
  end

  def duration_in_days
    (occurs_at - reminds_at).to_i
  end

  def title_for_remindable
    # Extracted method that calculated text_max_len from entity and assigned
    # the value in this assignment.
    text_max_len = 60
    case remindable_type
    when "Act"
      remindable.description.truncate(text_max_len)
    when "Audit"
      remindable.title.truncate(text_max_len)
    when "Groupgraph"
      remindable.title
    end
  end
end
