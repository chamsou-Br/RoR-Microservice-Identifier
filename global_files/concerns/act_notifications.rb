# frozen_string_literal: true

# This module adds methods to handle notifications when the state changes
#
module ActNotifications
  extend ActiveSupport::Concern

  def notifs_create_please
    log_workflow(@act, @comment)
    notify_by_role(@act, :create_act,
                   "owner", "validator", "contributor")
  end

  def notifs_start_processing
    log_workflow(@act, @comment)
    notify_by_role(@act, :realize_act,
                   "validator", "contributor")
    notify_by_role(@act, :realize_act_to_owner, "owner")
  end

  def notifs_ask_approval
    log_workflow(@act, @comment)
    notify_by_role(@act, :complete_act,
                   "owner", "author", "validator", "contributor")
  end

  def notifs_close_action
    # Notifications for action closed
    log_workflow(@act, @comment)
    notice_key = case @act.field_item_key("efficiency")
                 when "efficient"
                   :close_efficient_act
                 when "not_efficient"
                   :close_not_efficient_act
                 else # "not_checked" or nil
                   :close_not_checked_act
                 end
    notify_by_role(@act, notice_key,
                   "owner", "author", "validator", "contributor")

    return unless notice_key == :close_efficient_act

    # Notifications for event auto close if needed
    # Assuming that if the event is closed today, it was autoclosed due the
    # action closing. At the moment there is no way of checking with 100%
    # certainty, that this is the case.
    @act.events.each do |event|
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

  def notifs_cancel_action
    log_workflow(@act, @comment)
    notify_by_role(@act, :cancel_act,
                   "owner", "author", "validator", "contributor")

    # Notify the event.owner of which this action is part of its PA
    @act.events.each do |e|
      notify_by_role(e, :cancel_act, "owner")
    end
  end
end
