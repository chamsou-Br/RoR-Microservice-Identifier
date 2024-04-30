# frozen_string_literal: true

# This module adds methods to handle notifications when the event is modified.
#
module EventNotifications
  def event_create_notice
    log_operation(@entity, @operation)
    return unless @entity.under_analysis?

    notify_by_role(@entity, :create_event, "owner")
    notify_by_role(@entity, :cim_create_event, "cim", "validator")
  end

  ## BEGIN: Notices direct consequence of transitions.
  def event_create_please
    log_workflow(@entity, @comment)
    notify_by_role(@entity, :event_under_analysis_from_audit, "owner", "cim")
  end

  def event_close_event
    log_workflow(@entity, @comment)
    notify_by_role(@entity, :close_event_no_action_plan, "author",
                   "contributor")
    notifs_audits_autoclose(@entity)
  end

  # This method should be modified if the pending_forced_closure state is
  # permanently deleted. The next 2 shall be deleted.
  #
  def event_force_close
    log_workflow(@entity, @comment)
    if @entity.closed?
      notify_by_role(@entity, :close_event_forced,
                     "author", "contributor", "cim", "validator")
      notifs_audits_autoclose(@entity)
    elsif @entity.pending_forced_closure?
      notify_by_role(@entity, :approved_event_forced,
                     "author", "contributor", "owner", "validator")
      notify_by_role(@entity, :cim_approved_event_forced, "cim")
    end
  end

  # To be deleted if the pending_forced_closure state is permanently deleted.
  def event_approve_force_close
    log_workflow(@entity, @comment)
    log_validator_operation(@entity, @comment)
    notify_by_role(@entity, :close_event_forced,
                   "author", "contributor", "cim", "owner")
    notifs_audits_autoclose(@entity)
  end

  # To be deleted if the pending_forced_closure state is permanently deleted.
  def event_refuse_force_close
    log_workflow(@entity, @comment)
    log_validator_operation(@entity, @comment)
    notify_by_role(@entity, :refuse_event_force,
                   "author", "contributor", "cim", "validator", "owner")
  end

  def event_start_processing
    log_workflow(@entity, @comment)
    notify_by_role(@entity, :approve_action_plan,
                   "author", "contributor", "cim", "validator", "owner")
    notify_event_actors
  end

  # The message at the moment is the same as an owner approving actions.
  # TODO: the meesage should include the fact that the admin approved and
  # other validations were waived.
  def event_admin_approve
    log_workflow(@entity, @comment)
    notify_by_role(@entity, :approve_action_plan,
                   "author", "contributor", "cim", "validator", "owner")
    notify_event_actors
  end

  def event_ask_approval
    log_workflow(@entity, @comment)
    notify_by_role(@entity, :request_action_plan_validation,
                   "author", "contributor")
    notify_by_role(@entity, :cim_request_action_plan_validation,
                   "cim", "validator")
  end

  def event_ask_closure_approval
    log_workflow(@entity, @comment)
    notify_by_role(@entity, :request_closure_event,
                   "author", "contributor")
    notify_by_role(@entity, :cim_request_closure_event,
                   "cim", "validator")
  end

  def event_back_to_analysis
    log_workflow(@entity, @comment)
    notify_by_role(@entity, :back_to_analysis,
                   "author", "contributor", "cim", "validator")
    notify_by_role(@entity, :owner_re_analysis,
                   "owner")
  end

  def event_approve_action_plan
    log_validator_operation(@entity, @comment)
    return unless @entity.completed?

    log_workflow(@entity, @comment)
    notify_by_role(@entity, :approve_action_plan,
                   "author", "contributor", "cim", "validator", "owner")
    notify_event_actors
  end

  def event_approve_closure
    notifs_and_logs(:close_event_no_action_plan)
    notifs_audits_autoclose(@entity)
  end

  def event_refuse_closure
    notifs_and_logs(:cim_refuse_closure_event)
  end

  def event_refuse_action_plan
    notifs_and_logs(:cim_refuse_action_plan)
  end
  ## END: Notices direct consequence of transitions.

  def notifs_and_logs(category)
    log_validator_operation(@entity, @comment)
    log_workflow(@entity, @comment)
    notify_by_role(@entity, category,
                   "author", "contributor", "cim", "validator", "owner")
  end

  def notify_event_actors
    @entity.acts.each do |a|
      notify_by_role(a, :create_act, "owner", "validator") if a.planned?
    end
  end
end
