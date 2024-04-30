# frozen_string_literal: true

# NOTE: 2019-03-01
# This is the new acts_controller, where new methods to replace old ones will
# live.
# At the moment it inherets from Improver::BaseController as-is. Not checking
# or reading has been done in that controller yet. However the modules included
# in the original controller, are not included here, unless needed.
#
# Note: 2019-02-18
# Changing inheritance as the user_not_authorized method was not appropriate.
#
class ActsController < SpaController
  include WorkflowProps
  include ImproverTwoHelpers
  include NotificationMethods

  def index
    acts = policy_scope(current_customer.acts).includes(
      :author, :owner, :contributors, :validators,
      fieldable_values: %i[form_field entity]
    )

    @acts = { acts: acts.map { |a| a.act_hashed(current_user) } }

    respond_to do |format|
      format.json do
        render json: @acts
      end
    end
  end

  # For a new action, the front-end uses a rest endpoint (this one) and a
  # graphql endpoint. This endpoint provides the html layout and json of
  # involvable_users. The graphql provides all related data of the fieldable.
  def new
    respond_to do |format|
      format.json do
        render json: {
          involvable_responsibilities: possible_responsibilities(Act)
        }.as_json
      end
    end
  end

  def create
    @act = Act.new(act_params.merge(customer: current_customer))
    authorize @act

    # These methods are part of the module ImproverTwoHelpers.
    # This allows reuse in other controllers: @event and @audit.
    process_state(params["act"]["state"], @act)
    process_responsibilities(@act, "act_author")
    process_fieldables(@act)
    new_internal_ref(@act)

    save_and_render(@act)

    # Notifications
    create_notice(@act) if @act.errors.blank?
  end

  def show
    @act = current_customer.acts.find(params[:id])
    authorize(@act)

    @act.validate_all_fields

    respond_to do |format|
      format.json do
        render json: { act: fields_entity(@act),
                       involvable_users: possible_responsibilities(Act),
                       errors: @act.errors.full_messages }
      end
    end
  end

  def update
    @act = current_customer.acts.find(params[:id])
    @act.assign_attributes(act_params)
    process_fieldables(@act)

    respond_to do |format|
      format.html do
        render layout: "improver_modern"
      end
      format.json do
        save_and_render(@act)
      end
    end
    log_operation(@act) if @act.errors.blank?
  end

  # TODO: the update_workflow in events_controller is a carbon copy of this.
  # There might be room for refactoring or redesign.
  def update_workflow
    @act = current_customer.acts.find_by(id: params[:id])
    @comment = params[:comment]
    @transition = params[:transition]

    error_msgs = find_errors(@act)
    if error_msgs.any?
      render json: { errors: error_msgs }, status: :bad_request
      return
    end

    authorize(@act, "#{@transition}?")

    validator_response if @transition == "close_action"

    if @act.send(@transition)
      transition_notice(@act)
      render json: workflow_props(@act), status: :ok
    else
      errors = @act.errors.full_messages
      render json: { errors: errors }.merge(workflow_props(@act)),
             status: :ok
    end
  end

  def update_responsibilities
    @act = current_customer.acts.find_by(id: params[:id])
    unless @act
      render json: {
        errors: { errors: ["There was no action to update role to."] }
      }, status: :bad_request
      return
    end

    authorize(@act, "edit_roles?")
    process_responsibilities(@act)
    save_and_render(@act)

    return if @act.errors.present?

    log_operation(@act, "update")
    notify_update_responsibilities(@act)
  end

  def destroy
    @act = current_customer.acts.find(params[:id])
    authorize @act
    events = @act.events.to_a
    if @act.destroy
      events.each do |event|
        log_workflow(event, "Part of the PA of this event, was deleted.")
      end
      message = "Action has been deleted."
    else
      message = "An error occured while deleting the Action."
    end

    respond_to do |format|
      format.json do
        render json: { message: message, act: { title: @act.title } }
      end
    end
  end

  private

  def act_params
    params.require(:act).permit(
      fieldable_values_attributes: %i[
        id value form_field_id entity_id entity_type _destroy
      ]
    )
  end

  def validator_response
    return if @act.acts_validators.empty?

    response = @act.field_item_key("efficiency")
    response_int = Act.efficiencies[response]
    response_params = { response: response_int, response_at: Date.today }
    @act.acts_validators
        .find_by(validator_id: current_user.id)
        &.update(response_params)
  end

  def comment_required?(transition)
    # Comment needs to be present when the action is cancelled or closed not efficient.
    (transition == "close_action" && !@act.efficient?) || transition == "cancel_action"
  end
end
