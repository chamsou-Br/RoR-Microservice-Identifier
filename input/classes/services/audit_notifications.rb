# frozen_string_literal: true

# This module adds methods to handle notifications when the audit is modified.
#
module AuditNotifications
  def audit_create_notice
    log_operation(@entity, @operation)
    notify_by_role(@entity, :create_audit, "owner")
  end

  ## BEGIN: Notices direct consequence of transitions.
  def audit_finish_planning
    log_workflow(@entity, @comment)
    notify_by_role(@entity, :audit_planned,
                   "contributor", "organizer", "owner",
                   "auditor", "auditee", "domain_owner")
  end

  def audit_start_processing
    log_workflow(@entity, @comment)
    notify_by_role(@entity, :audit_in_progress, "contributor", "organizer")
  end

  def audit_finish_audit
    log_workflow(@entity, @comment)
    notify_by_role(@entity, :audit_report_waiting_for_approval,
                   "contributor", "auditor")
    notify_by_role(@entity, :audit_approbation_request, "organizer")
  end

  def audit_approve_report
    log_workflow(@entity, @comment)
    notify_by_role(@entity, :audit_finished_satisfied,
                   "contributor", "owner", "contributor",
                   "auditor", "auditee", "domain_owner")
  end

  def audit_refuse_report
    log_workflow(@entity, @comment)
    notify_by_role(@entity, :audit_refused, "owner", "contributor",
                   "auditor", "auditee", "domain_owner")
  end

  def audit_back_in_progress
    log_workflow(@entity, @comment)
    notify_by_role(@entity, :audit_back_in_progress, "owner", "organizer",
                   "contributor", "auditor", "auditee", "domain_owner")
  end

  def audit_force_close
    log_workflow(@entity, @comment)
    notify_by_role(@entity, :audit_force_close, "owner", "organizer",
                   "contributor", "auditor", "auditee", "domain_owner")
  end
  ## END: Notices direct consequence of transitions.
end
