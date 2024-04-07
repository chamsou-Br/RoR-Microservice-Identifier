# frozen_string_literal: true

# == Schema Information
#
# Table name: new_notifications
#
#  id                       :integer          not null, primary key
#  category                 :integer
#  from_id                  :integer
#  to_id                    :integer
#  entity_id                :integer
#  entity_type              :string(255)
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  checked_at               :datetime
#  customer_id              :integer
#  notification_roles       :text(65535)
#  mailed                   :datetime
#  mail_delivered_frequency :string(255)
#
# Indexes
#
#  index_new_notifications_on_created_at                 (created_at)
#  index_new_notifications_on_customer_id                (customer_id)
#  index_new_notifications_on_entity_id_and_entity_type  (entity_id,entity_type)
#  index_new_notifications_on_from_id                    (from_id)
#  index_new_notifications_on_to_id                      (to_id)
#

class NewNotification < ApplicationRecord
  enum category: {
    unknown: 0,
    add_contributor: 1,
    new_contribution: 2,
    change_pilot: 3,
    change_author: 4,
    sent_verification_author: 5,
    sent_verification_pilot: 6,
    verification_request_author: 7,
    verification_request_pilot: 8,
    verification_request_other: 9,
    sent_approval_author: 10,
    sent_approval_pilot: 11,
    approval_request_author: 12,
    approval_request_pilot: 13,
    approval_request_other: 14,
    sent_publication_author: 15,
    sent_publication_pilot: 16,
    publication_request_author: 17,
    publication_request_pilot: 18,
    publication_request_other: 19,
    applicable_author: 20,
    applicable_pilot: 21,
    applicable_other: 22,
    refusal_author: 23,
    refusal_pilot: 24,
    refusal_other: 25,
    create_event: 26,
    change_owner: 27,
    request_action_plan_validation: 28,
    approve_action_plan: 29,
    close_action_plan: 30,
    refuse_action_plan: 31,
    create_act: 32,
    realize_act: 33,
    cancel_act: 34,
    complete_act: 35,
    close_not_checked_act: 36,
    close_efficient_act: 37,
    close_not_efficient_act: 38,
    reminder_act_estimated_start_at: 39,
    reminder_act_estimated_closed_at: 40,
    realize_act_to_author: 41,
    realize_act_to_owner: 42,
    realize_act_to_event_owner: 43,
    realize_act_to_author_and_owner: 44,
    reminder_audit_estimated_start_at: 45,
    reminder_audit_estimated_closed_at: 46,
    create_audit: 47,
    audit_change_organizer: 48,
    audit_change_owner: 49,
    audit_planned: 53,
    audit_in_progress: 54,
    audit_report_waiting_for_approval: 55,
    audit_approbation_request: 56,
    audit_finished_satisfied: 57,
    audit_finished_not_satisfied: 58,
    audit_refused: 59,
    audit_manual_close: 60,
    audit_auto_close: 61,
    realize_act_from_event: 62,
    audit_assignment: 63,
    event_under_analysis_from_audit: 64,
    deactivated_author: 65,
    deactivated_pilot: 66,
    deactivated_other: 67,
    reactivated_author: 68,
    reactivated_pilot: 69,
    reactivated_other: 70,
    read_confirmation: 71,
    reminder_graph_review_date: 72,
    update_instance_ownership: 73,
    reminder_graph_review_date_changed: 74,
    connection_request: 75,
    connection_established: 76,
    max_graphs_and_docs_reached: 77,
    max_graphs_and_docs_approching: 78,
    cim_request_action_plan_validation: 79,
    cim_request_closure_event: 80,
    cim_refuse_closure_event: 81,
    cim_validate_action_plan: 82,
    cim_refuse_action_plan: 83,
    cim_action_plan_approved: 84,
    act_eval_efficiency: 85,
    cim_create_event: 86,
    request_closure_event: 87,
    close_event_forced: 88,
    close_event_no_action_plan: 89,
    back_to_analysis: 90,
    approve_event_forced: 91,
    cim_approve_event_forced: 92,
    refuse_event_forced: 93,
    owner_re_analysis: 94,
    act_assignment: 95,
    event_assignment: 96,
    audit_back_in_progress: 97,
    audit_force_close: 98
  }

  OPTIONS = {
    unknown: { type: "information", with_roles: false },
    add_contributor: { type: "action", with_roles: false },
    new_contribution: { type: "information", with_roles: false },
    change_pilot: { type: "information", with_roles: false },
    change_author: { type: "information", with_roles: false },
    sent_verification_author: { type: "information", with_roles: false },
    sent_verification_pilot: { type: "information", with_roles: false },
    verification_request_author: { type: "action", with_roles: false },
    verification_request_pilot: { type: "action", with_roles: false },
    verification_request_other: { type: "action", with_roles: false },
    sent_approval_author: { type: "information", with_roles: false },
    sent_approval_pilot: { type: "information", with_roles: false },
    approval_request_author: { type: "action", with_roles: false },
    approval_request_pilot: { type: "action", with_roles: false },
    approval_request_other: { type: "action", with_roles: false },
    sent_publication_author: { type: "information", with_roles: false },
    sent_publication_pilot: { type: "information", with_roles: false },
    publication_request_author: { type: "action", with_roles: false },
    publication_request_pilot: { type: "action", with_roles: false },
    publication_request_other: { type: "action", with_roles: false },
    applicable_author: { type: "information", with_roles: false },
    applicable_pilot: { type: "information", with_roles: false },
    applicable_other: { type: "information", with_roles: false },
    refusal_author: { type: "information", with_roles: false },
    refusal_pilot: { type: "information", with_roles: false },
    refusal_other: { type: "information", with_roles: false },
    create_event: { type: "action", with_roles: false },
    change_owner: { type: "information", with_roles: false },
    request_action_plan_validation: { type: "information", with_roles: true },
    approve_action_plan: { type: "information", with_roles: true },
    close_action_plan: { type: "information", with_roles: true },
    refuse_action_plan: { type: "information", with_roles: true },
    create_act: { type: "action", with_roles: true },
    realize_act: { type: "information", with_roles: true },
    cancel_act: { type: "information", with_roles: true },
    complete_act: { type: "information", with_roles: true },
    close_not_checked_act: { type: "information", with_roles: true },
    close_efficient_act: { type: "information", with_roles: true },
    close_not_efficient_act: { type: "information", with_roles: false },
    reminder_act_estimated_start_at: { type: "information", with_roles: false },
    reminder_act_estimated_closed_at: { type: "information", with_roles: false },
    realize_act_to_author: { type: "information", with_roles: false },
    realize_act_to_owner: { type: "action", with_roles: false },
    realize_act_to_event_owner: { type: "information", with_roles: false },
    realize_act_to_author_and_owner: { type: "action", with_roles: false },
    reminder_audit_estimated_start_at: { type: "information", with_roles: false },
    reminder_audit_estimated_closed_at: { type: "information", with_roles: false },
    create_audit: { type: "action", with_roles: false },
    audit_change_organizer: { type: "information", with_roles: false },
    audit_change_owner: { type: "information", with_roles: false },
    audit_planned: { type: "information", with_roles: true },
    audit_in_progress: { type: "information", with_roles: true },
    audit_report_waiting_for_approval: { type: "information", with_roles: true },
    audit_approbation_request: { type: "action", with_roles: false },
    audit_finished_satisfied: { type: "information", with_roles: true },
    audit_finished_not_satisfied: { type: "information", with_roles: true },
    audit_refused: { type: "information", with_roles: true },
    audit_manual_close: { type: "information", with_roles: true },
    audit_auto_close: { type: "information", with_roles: true },
    realize_act_from_event: { type: "information", with_roles: true },
    audit_assignment: { type: "information", with_roles: true },
    event_under_analysis_from_audit: { type: "action", with_roles: false },
    deactivated_author: { type: "information", with_roles: false },
    deactivated_pilot: { type: "information", with_roles: false },
    deactivated_other: { type: "information", with_roles: false },
    reactivated_author: { type: "information", with_roles: false },
    reactivated_pilot: { type: "information", with_roles: false },
    reactivated_other: { type: "information", with_roles: false },
    read_confirmation: { type: "action", with_roles: false },
    reminder_graph_review_date: { type: "actions", with_roles: false },
    update_instance_ownership: { type: "information", with_roles: false },
    reminder_graph_review_date_changed: { type: "action", with_roles: false },
    connection_request: { type: "action", with_roles: false },
    connection_established: { type: "information", with_roles: false },
    max_graphs_and_docs_reached: { type: "information", with_roles: false },
    max_graphs_and_docs_approching: { type: "information", with_roles: false },
    cim_request_action_plan_validation: { type: "action", with_roles: true },
    cim_request_closure_event: { type: "action", with_roles: true },
    cim_refuse_closure_event: { type: "information", with_roles: true },
    cim_validate_action_plan: { type: "information", with_roles: true },
    cim_refuse_action_plan: { type: "information", with_roles: true },
    cim_action_plan_approved: { type: "information", with_roles: true },
    act_eval_efficiency: { type: "action", with_roles: true },
    cim_create_event: { type: "information", with_roles: true },
    request_closure_event: { type: "action", with_roles: true },
    close_event_forced: { type: "information", with_roles: true },
    close_event_no_action_plan: { type: "information", with_roles: true },
    back_to_analysis: { type: "information", with_roles: true },
    approve_event_forced: { type: "information", with_roles: true },
    cim_approve_event_forced: { type: "information", with_roles: true },
    refuse_event_forced: { type: "information", with_roles: true },
    owner_re_analysis: { type: "action", with_roles: true },
    act_assignment: { type: "information", with_roles: true },
    event_assignment: { type: "information", with_roles: true },
    audit_back_in_progress: { type: "information", with_roles: true },
    audit_force_close: { type: "information", with_roles: true }
  }.freeze

  serialize :notification_roles
  belongs_to :customer

  # @!attribute [rw] from
  #   @return [User]
  belongs_to :from, class_name: "User", optional: true

  # @!attribute [rw] to
  #   @return [User]
  belongs_to :to, class_name: "User"

  belongs_to :entity, polymorphic: true

  has_many :favorites, as: :favorisable, dependent: :destroy
  has_many :likers, through: :favorites, source: :user

  validates :category, :customer, :entity, :to, presence: true

  before_destroy do
    entity.destroy if entity.is_a?(Reminder)
  end

  # If `checked_at` is set, the notification is assumed to have been read.  This
  # assumes some validation rules prevent `checked_at` from being set to future
  # dates.
  scope :read, -> { where.not(checked_at: nil) }
  scope :unread, -> { where(checked_at: nil) }

  def option(opt)
    # FIXME: The same as in method notification_type, it seems to happen
    # though, that category is nil and there is a 500 error.
    category.nil? ? OPTIONS[:unknown][opt] : OPTIONS[category.to_sym][opt]
  end

  def notification_type
    # FIXME: There are no `NewNotification` models persisted with a `nil`
    # `category`, so it is unclear why this happens.
    # Update: 20190808, found an occurence of category == nil, however, I still
    # got a 500 error. @akudashkin confirmed there no nil categories in prod.
    category.nil? ? "unknown" : OPTIONS[category.to_sym][:type]
  end

  def read?
    !!checked_at
  end

  def read!
    update_attribute(:checked_at, DateTime.now)
  end

  def unread!
    update_attribute(:checked_at, nil)
  end

  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity
  def entity_url
    helpers = Rails.application.routes.url_helpers
    host = { host: customer.url }
    case entity.class.name
    when "Graph" then helpers.graph_url(entity, host)
    when "Document" then helpers.show_properties_document_url(entity, host)
    when "Contribution"
      host = host.merge(contribution: entity)
      case entity.contributable.class.name
      when "Graph" then helpers.graph_url(entity.contributable, host)
      when "Event" then helpers.improver_event_url(entity.contributable, host)
      when "Act" then helpers.improver_action_url(entity.contributable, host)
      when "Audit" then helpers.improver_audit_url(entity.contributable, host)
      end
    when "Event" then helpers.improver_event_url(entity, host)
    when "Act" then helpers.improver_action_url(entity, host)
    when "Reminder" then entity.remindable_url(helpers, host)
    when "Audit" then helpers.improver_audit_url(entity, host)
    end
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity

  # TODO: Refactor `entity_path`
  # Seems like this method is returning appropriate URL paths for a given entity
  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity
  def entity_path
    helpers = Rails.application.routes.url_helpers
    case entity.class.name
      # Special case when setting an owner.
    when "User"
      helpers.dashboard_index_path if category == "update_instance_ownership"
      # End special owner case.
    when "Graph" then helpers.graph_path(entity)
    when "Document" then helpers.show_properties_document_path(entity)
    when "Contribution"
      contribution = { contribution: entity }
      case entity.contributable.class.name
      when "Graph" then helpers.graph_path(entity.contributable, contribution)
      when "Event" then helpers.improver_event_path(entity.contributable, contribution)
      when "Act" then helpers.improver_action_path(entity.contributable, contribution)
      when "Audit" then helpers.improver_audit_path(entity.contributable, contribution)
        # when 'Document'; helpers.document_path(entity.contributable, contribution)
      end
    when "Event" then helpers.improver_event_path(entity)
    when "Act" then helpers.improver_action_path(entity)
    when "Reminder" then entity.remindable_path(helpers)
    when "Audit" then helpers.improver_audit_path(entity)
    when "StoreConnection" then helpers.store_connections_path
    end
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity

  # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  # rubocop:disable Metrics/MethodLength
  # TODO: Refactor `entity_title` to use safe_navigation or `#try`
  def entity_title
    # This assignemnt replaces a convoluted way of calculaitng the maximun
    # length of text, which ultimately all resulted in... 63.
    text_max_len = 63
    entity = self.entity

    case entity
    when Contribution
      entity = self.entity.contributable
    when Reminder
      return (entity.remindable.nil? ? nil : entity.title_for_remindable)
    when User
      return
    end

    if entity.respond_to?(:title)
      entity.title
    elsif entity.respond_to?(:name)
      entity.name
    elsif entity.respond_to?(:label)
      entity.label
    elsif entity.respond_to?(:description)
      entity.description.truncate text_max_len
    elsif entity.respond_to?(:object)
      entity.object.truncate text_max_len
    end
  end
  # rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  # rubocop:enable Metrics/MethodLength

  # When user's mail frequency is daily or weekly: the email is scheduled by
  # sidekiq using cron.
  # TODO: there are no tests for this.
  # TODO: `create!` should be used instead to raise an exception when the
  # notification is not created to indicate that an email will not be sent and
  # that no timeline logging will take place.
  #
  def self.create_and_deliver(params, extra = "", emergency = false)
    notification = NewNotification.create(params)
    if notification
      logger.info("[Success] Created notification #{notification.category}")
      # Si le flag est à false ou que le user veut du real_time
      if notification.to.mail_frequency == "real_time" || emergency
        NotificationMailer.notify_user(notification, extra).deliver_now
        notification.update(mailed: DateTime.now, mail_delivered_frequency: "real_time")
      elsif notification.to.mail_frequency == "none"
        notification.update(mail_delivered_frequency: "none")
      end
    else
      logger.warn("[Fail] notification with params #{params}")
    end
  end

  def self.sidekiq_call_scheduled_notify_users(user_id, mail_delivered_frequency = "daily")
    logger.debug "--> In NewNotification.sidekiq_call_scheduled_notify_users."
    logger.debug "--> delivering #{mail_delivered_frequency} mail for user(id=#{user_id})..."
    user = User.find(user_id)
    notifications = user.new_notifications.mailable
    return if notifications.nil?

    NotificationMailer.scheduled_notify_user(user, notifications).deliver_now
    notifications.update_all(mailed: DateTime.now, mail_delivered_frequency: mail_delivered_frequency)
  end

  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  # This method is called by the rake task rake mail_frequency:cron_call_scheduled_notify_users
  # To deal with the customer's email notif set to weekly or daily.
  def self.cron_call_scheduled_notify_users
    logger.debug "--> In NewNotification.scheduled_notify_users."

    # Etape1 : Selection des time_zone existantes et détermination du jour et de l'heure locale
    time_zones = (
      User.distinct.where.not(time_zone: nil).pluck(:time_zone) +
      CustomerSetting.distinct.where.not(time_zone: nil).pluck(:time_zone)
    ).uniq
    time_zones.each do |time_zone|
      time_zone_day = Time.now.in_time_zone(time_zone).wday
      # 0 = Sunday .. 6 = Saturday
      time_zone_hour = Time.now.in_time_zone(time_zone).hour
      # Etape2 : Gestion des weekly
      # 2.1 : Pour chacune des time_zone, selection des users répondant aux
      # critères (time_zone, weekly, day, hour, etc.)
      users = User.active.with_time_zone(time_zone)
                  .with_mail_frequency_params("weekly", time_zone_hour, time_zone_day)
                  .having_mailable_new_notifications
      logger.debug "--> for time_zone '#{time_zone}', weekly picked users are : #{users.inspect} "
      # 2.2 : Pour chaque user, creation du job associé.
      users.each do |user|
        logger.debug "--> preparing weekly job for user(id=#{user.id})"
        SendScheduledNotifyUserWorker.perform_async(user.id, "weekly")
        logger.debug "--> preparation done : weekly job for user(id=#{user.id})"
      end

      # Etape3 : Gestion des daily
      # 3.1 : Pour chacune des time_zone, selection des users répondant aux
      # critères (time_zone, weekly, day, hour, etc.)
      users = User.active.with_time_zone(time_zone)
                  .with_mail_frequency_params("daily", time_zone_hour)
                  .having_mailable_new_notifications
      logger.debug "--> for time_zone '#{time_zone}', daily picked users are : #{users.inspect} "
      # 3.2 : Pour chaque user, creation du job associé.
      users.each do |user|
        logger.debug "--> preparing daily job for user(id=#{user.id})"
        SendScheduledNotifyUserWorker.perform_async(user.id, "daily")
        logger.debug "--> preparing done : daily job for user(id=#{user.id})"
      end
    end
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

  def self.mailable
    where(mailed: nil, mail_delivered_frequency: nil)
  end

  def improver?
    # for contribution
    return true if [Act, Event, Audit].include?(entity.class)
    return true if entity.instance_of?(Contribution) &&
                   [Act, Event, Audit].include?(entity.contributable.class)

    (26..64).collect.to_a.include? NewNotification.categories[category]
  end
end
