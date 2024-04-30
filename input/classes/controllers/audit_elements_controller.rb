# frozen_string_literal: true

# This controller replaces
# app/controllers/improver/audits/elements_controller.rb
#
class AuditElementsController < ApplicationController
  include ImproverNotifications
  include NotificationMethods

  def create
    @audit = current_customer.audits.find(params[:audit_id])
    authorize @audit, :audit_plan?

    @audit_element = AuditElement.new(
      audit_element_params.merge(audit_id: @audit.id)
    )
    element_with_process if params[:process_id] && params[:process_type]

    # There are three roles for the audit element: auditor, auditee (audited)
    # and domain owner (domain responsible). These roles should be provided
    # by the front-end. If not provided:
    # * The auditor defaults to the audit's owner.
    # * The domain owner defaults to the process pilot if it exists.
    assign_roles

    if @audit_element.save
      create_field_value
      @audit.mark_dirty_audit_element_ids(nil)
      log_operation(@audit, "update")
    else
      errors = @audit_element.errors.full_messages
    end
    render json: { audit_element: { id: @audit_element.id }, errors: errors }
  end

  def update
    @audit_element = AuditElement.find(params[:id])
    authorize @audit_element

    @audit_element.update(audit_element_params)
    assign_provided_roles

    if params[:process_id] && params[:process_type]
      element_with_process
    else
      @audit_element.assign_attributes(process_id: nil, process_type: nil)
    end

    errors = @audit_element.errors.full_messages unless @audit_element.save
    render json: { audit_element: { id: @audit_element.id }, errors: errors }
  end

  def destroy
    @audit_element = AuditElement.find(params[:id])
    @audit = @audit_element.audit
    authorize @audit_element

    if @audit_element.destroy
      # FIXME: Since field values weren't previously deleted, there will exist
      # many orphan field values that will need to be cleaned up with a Rake
      # task.
      delete_field_value(params[:id])
      @audit.mark_dirty_audit_element_ids(nil)
      log_operation(@audit, "update")
      message = "Audit element deleted"
    else
      message = "Audit element could not be deleted"
    end

    render json: { message: message,
                   audit_element: { subject: @audit_element.subject } }
  end

  private

  def create_field_value
    form_field = @audit.form_field_object(:audit_elements)
    @audit.fieldable_values << FieldValue.new(form_field: form_field,
                                              entity_type: "AuditElement",
                                              entity_id: @audit_element.id)
  end

  def delete_field_value(id)
    form_field = @audit.form_field_object(:audit_elements)
    field_value = @audit.fieldable_values.find_by(form_field: form_field,
                                                  entity_type: "AuditElement",
                                                  entity_id: id)
    @audit.fieldable_values.delete(field_value) if field_value
  end

  def element_with_process
    processes = params[:process_type].downcase.pluralize
    @process = current_customer.send(processes).find(params[:process_id])
    @audit_element.assign_attributes(
      process_id: @process.id,
      process_type: @process.class.to_s
    )
  end

  def assign_roles
    assign_provided_roles

    default_auditor
    default_domain_owner
  end

  # If involved params provided, this method will delete all previous
  # occurrence and create new records with the provided roles and users.
  def assign_provided_roles
    return unless params["involved_responsibilities"]

    @audit_element.audit_participants.delete_all

    params["involved_responsibilities"].each do |resp|
      resp_map = { auditor: "auditor",
                   auditee: "audited",
                   domain_owner: "domain_responsible" }
      resp[:user_ids].each do |uid|
        @audit_element.audit_participants.build(
          participant: User.find(uid),
          resp_map[resp[:responsibility].to_sym] => true
        )
      end
    end
  end

  def default_auditor
    unless @audit_element.auditors.empty? &&
           params[:involved_responsibilities].nil?
      return
    end

    @audit_element.audit_participants.build(
      participant: @audit.owner, auditor: true
    )
  end

  def default_domain_owner
    return if @audit_element.domain_responsible
    return unless @process&.pilot

    @audit_element.audit_participants.build(
      participant: @process.pilot, domain_responsible: true
    )
  end

  def audit_element_params
    params.require(:audit_element).permit(%i[subject start_date end_date])
  end
end
