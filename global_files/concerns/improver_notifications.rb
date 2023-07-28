# frozen_string_literal: true

# This module adds methods to handle notifications when the state changes
#
module ImproverNotifications
  extend ActiveSupport::Concern

  def notify_by_role(entity, category, *roles)
    all_users = []
    roles.each do |role|
      case role
      when /(author)/, /(organizer)/, /^(owner)$/
        all_users << entity.send(role.to_s)
      when /(validator)/, /(contributor)/, /(domain_owner)/, /(auditor)/, /(auditee)/
        all_users += entity.send("#{role}s")
      when "cim"
        all_users += entity.cims
      end
    end

    recipients = (all_users - [current_user]).uniq
    email_and_notif_for(recipients, entity, category)
  end

  def notify_update_roles(entity)
    category = "#{entity.class.to_s.downcase}_assignment".to_sym
    user_ids = @responsibilities_changed.map(&:last).flatten.uniq
    recipients = User.find(user_ids)
    email_and_notif_for(recipients, entity, category)
  end

  def notifs_audits_autoclose(entity)
    # Notify the audit which would have been autoclosed by closing the event.
    entity.audits.each do |audit|
      # Only send a notification if the audit was closed today.
      next unless audit.closed? && audit.real_closed_at == Date.today

      # TODO: given that the instance controller is the event, the transition
      # that will be logged is the one used of the event, not for the audit.
      # Technically, that is wrong, the TimelineAudit should be logging the
      # audit transition.
      log_workflow(audit, "autoclose")
      notify_by_role(audit, :audit_auto_close,
                     "organizer", "owner", "contributor",
                     "auditee", "auditor", "domain_owner")
    end
  end

  def email_and_notif_for(recipients, entity, category)
    recipients.each do |recipient|
      create_notification(
        category: category,
        to: recipient,
        entity: entity,
        notification_roles: entity.notification_roles_for(recipient)
      )
    end
  end

  # Actual notifications and logs
  def create_notification(options = {})
    notif = { customer: current_customer, from: current_user }.merge(options)
    NewNotification.create_and_deliver(notif)
  end

  ## log_aciton and log_workflow are essentiallly the same, one saves any
  # action (as implemented originally) and the second assigns workflow to action
  # to identify the transitons from any other stuff happenning.
  # log_action is being used, not sure of this use will persist after release.
  # This needs reviewing one day.
  #
  # Logs an entry for `action` in the `timeline_items` for `entity` having
  # current_user as `author`, with optional `comment`, unless no attributes
  # are marked as dirty since the last time `entity` was saved and no
  # associations were changed since it was last logged in the timeline.
  #
  # 8 May 2019:
  # TODO: This method will become or already is useless as entities information
  # is now handled by fieldables. It has be rethought: what is this really used
  # for and what information do we really need. The object field as it currently
  # stands is awful.
  def log_action(entity, action, comment = "")
    attrs_changed = entity.saved_changes.map { |key, _value| key }
    filtered_hash = entity.serializable_hash(
      only: entity.attributes_to_track,
      methods: entity.many_associations_to_track
    ).delete_if do |key, _value|
      !attrs_changed.include?(key) && !entity.many_associations_to_track.include?(key)
    end
    return unless entity.object_has_changed?(action, filtered_hash)

    entity.timeline_items.create author: current_user,
                                 object: filtered_hash.to_json,
                                 action: action,
                                 comment: comment
  end

  # Logs a workflow entry in the `timeline_items` for `entity` for current_user,
  # with optional `comment`. The method does not check for object changes,
  # it will log the transision and the state of the entity, as it is called
  # after a successful state change. Here we move away from 'object dirty' as
  # the state machine may update entity again in an `after_transition` block.
  #
  def log_workflow(entity, comment = "")
    entity.timeline_items.create author: current_user,
                                 object: { state: entity.state,
                                           transition: @transition }.to_json,
                                 action: "workflow",
                                 comment: comment
  end

  # Replacing @event.log_cim_action
  def log_validator_action(entity, comment = "")
    # Save the previous and the current value of what chagned.
    attrs_changed = entity.saved_changes
    attrs_changed["state"] = entity.state
    attrs_changed["role"] = "validator"
    # rubocop:disable Style/IfUnlessModifier
    if entity.respond_to?(:managed_by?) && entity.managed_by?(current_user)
      attrs_changed["role"] = "cim"
    end
    # rubocop:enable Style/IfUnlessModifier

    entity.timeline_items.create(
      author: current_user,
      action: "validation response",
      comment: comment,
      object: attrs_changed.to_json
    )
  end
end
