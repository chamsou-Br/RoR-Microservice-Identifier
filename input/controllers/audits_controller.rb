# frozen_string_literal: true

# NOTE: 2019-04-19
# This is the new audits_controller, where new methods to replace old ones will
# live.
# At the moment it inherets from Improver::BaseController as-is. Not checking
# or reading has been done in that controller yet. However the modules included
# in the original controller, are not included here, unless needed.
#
class AuditsController < SpaController
  include WorkflowProps
  include ImproverTwoHelpers
  include NotificationMethods

  def index
    audits = policy_scope(current_customer.audits).includes(
      :owner, :organizer, :contributors,
      fieldable_values: %i[form_field entity]
    )
    @audits = { audits: audits.map { |e| e.audit_hashed(current_user) } }

    respond_to do |format|
      format.json do
        render json: @audits
      end
    end
  end

  # For a new audit, the front-end uses a rest endpoint (this one) and a
  # graphql endpoint. This endpoint provides the html layout and json of
  # involvable_users. The graphql provides all related data of the fieldable.
  def new
    respond_to do |format|
      format.html do
        render layout: "improver_modern"
      end
      format.json do
        render json: {
          involvable_responsibilities: possible_responsibilities(Audit)
        }.as_json
      end
    end
  end

  def create
    @audit = Audit.new(audit_params.merge(customer: current_customer))
    authorize @audit

    # These methods are part of the module ImproverTwoHelpers.
    # This allows reuse in other controllers: @event and @audit.
    process_responsibilities(@audit, "audit_organizer")
    process_fieldables(@audit)
    new_internal_ref(@audit)

    save_and_render(@audit)

    # Notifications
    create_notice(@audit) if @audit.errors.blank?
  end

  def show
    @audit = current_customer.audits.find(params[:id])
    authorize(@audit)

    @audit.validate_all_fields

    respond_to do |format|
      format.html do
        render layout: "improver_modern"
      end
      format.json do
        render json: { audit: fields_entity(@audit),
                       involvable_users: possible_responsibilities(Audit),
                       errors: @audit.errors.full_messages }
      end
    end
  end

  def update
    @audit = current_customer.audits.find(params[:id])
    @audit.assign_attributes(audit_params)
    process_fieldables(@audit)

    respond_to do |format|
      format.html do
        render layout: "improver_modern"
      end
      format.json do
        save_and_render(@audit)
      end
    end
    log_operation(@audit) if @audit.errors.blank?
  end

  def update_responsibilities
    @audit = current_customer.audits.find_by(id: params[:id])
    unless @audit
      render json: {
        errors: { errors: ["There was no audit to update role to."] }
      }, status: :bad_request # 400
      return
    end

    authorize(@audit, "edit_roles?")
    process_responsibilities(@audit)
    save_and_render(@audit)

    return if @audit.errors.present?

    log_operation(@audit, "update")
    notify_update_responsibilities(@audit)
  end

  # TODO: the update_workflow in events_controller is a carbon copy of this.
  # There might be room for refactoring or redesign.
  def update_workflow
    @audit = current_customer.audits.find_by(id: params[:id])
    @comment = params[:comment]
    @transition = params[:transition]

    error_msgs = find_errors(@audit)
    if error_msgs.any?
      render json: { errors: error_msgs }, status: :bad_request
      return
    end

    authorize(@audit, "#{@transition}?")

    if @audit.send(@transition)
      transition_notice(@audit)
      render json: workflow_props(@audit), status: :ok
    else
      errors = @audit.errors.full_messages
      render json: { errors: errors }.merge(workflow_props(@audit)),
             status: :ok
    end
  end

  # rubocop: disable Metrics/AbcSize
  def duplicate
    old_audit = current_customer.audits.find_by(id: params[:id])

    authorize(old_audit, "show?")
    authorize(old_audit, "create?")

    @audit = old_audit.dup.tap do |audit|
      audit.state = "planning"
      audit.estimated_start_at = Time.now
      audit.estimated_closed_at = Time.now
      audit.real_closed_at = nil
      audit.real_started_at = nil
      audit.completed_at = nil
    end

    process_responsibilities(@audit, "audit_organizer")
    new_internal_ref(@audit)

    @audit.fieldable_values = old_audit.fieldable_values.map do |fv|
      fv.dup.tap do |new_fv|
        new_fv.fieldable = @audit
      end
    end

    save_and_render(@audit)
    create_notice(@audit) if @audit.errors.blank?
  end
  # rubocop: enable Metrics/AbcSize

  def destroy
    @audit = current_customer.audits.find(params[:id])
    authorize @audit
    # TODO: Need to log the action for all the associated actions and audits?
    # Next line is needed to turn the ActiveRecord Assoc into an array and grab
    # the actions before the audit is deleted.
    events = @audit.events.to_a
    if @audit.destroy
      # At the moment it is not clear what has to be done with the PA.
      events.each do |event|
        log_workflow(event, "The audit owning this event was deleted.")
      end
      message = "Audit has been deleted."
    else
      message = "An error occured while deleting the Audit."
    end

    respond_to do |format|
      format.json do
        render json: { message: message, audit: { title: @audit.title } }
      end
    end
  end

  private

  def audit_params
    params.require(:audit).permit(
      fieldable_values_attributes: %i[
        id value form_field_id entity_id entity_type _destroy
      ]
    )
  end

  def comment_required?(transition)
    %w[back_in_progress force_close refuse_report].include?(transition.to_s)
  end
end
