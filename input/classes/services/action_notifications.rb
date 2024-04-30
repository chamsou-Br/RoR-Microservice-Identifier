# frozen_string_literal: true

# This module adds methods to handle notifications when the action is modified.
#
module ActionNotifications
  def act_create_notice
    log_operation(@entity, @operation)
    return unless @entity.planned?

    notify_by_role(@entity, :create_act, "owner")
    notify_by_role(@entity, :act_assignment, "validator", "contributor")
  end

  ## BEGIN: Notices direct consequence of transitions.
  def act_create_please
    log_workflow(@entity, @comment)
    notify_by_role(@entity, :create_act,
                   "owner", "validator", "contributor")
  end

  def act_start_processing
    log_workflow(@entity, @comment)
    notify_by_role(@entity, :realize_act,
                   "validator", "contributor")
    notify_by_role(@entity, :realize_act_to_owner, "owner")
  end

  def act_ask_approval
    log_workflow(@entity, @comment)
    notify_by_role(@entity, :complete_act,
                   "owner", "author", "validator", "contributor")
  end

  def act_close_action
    # Notifications for action closed
    log_workflow(@entity, @comment)
    notice_key = case @entity.field_item_key("efficiency")
                 when "efficient"
                   :close_efficient_act
                 when "not_efficient"
                   :close_not_efficient_act
                 else # "not_checked" or nil
                   :close_not_checked_act
                 end
    notify_by_role(@entity, notice_key,
                   "owner", "author", "validator", "contributor")

    return unless notice_key == :close_efficient_act

    # Notifications for event auto close if needed
    # Assuming that if the event is closed today, it was autoclosed due the
    # action closing. At the moment there is no way of checking with 100%
    # certainty, that this is the case.
    @entity.events.each do |event|
      next unless event.closed? && event.closed_at == Date.today

      # TODO: given that the instance controller is the event, the transition
      # that will be logged is the one used of the act, not for the event.
      # Technically, that is wrong, the TimelineAudit should be logging the
      # audit transition.
      log_workflow(event, "autoclose")
      notify_by_role(event, :close_action_plan,
                     "owner", "author", "contributor", "cim")
      notifs_audits_autoclose(event)
    end
  end

  def act_cancel_action
    log_workflow(@entity, @comment)
    notify_by_role(@entity, :cancel_act,
                   "owner", "author", "validator", "contributor")

    # Notify the event.owner of which this action is part of its PA
    @entity.events.each do |e|
      notify_by_role(e, :cancel_act, "owner")
    end
  end
  ## END: Notices direct consequence of transitions.
end
