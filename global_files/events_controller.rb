# frozen_string_literal: true

# NOTE: 2019-02-06
# This is the new events_controller, where new methods to replace old ones will
# live.
# At the moment it inherets from Improver::BaseController as-is. Not checking
# or reading has been done in that controller yet. However the modules included
# in the original controller, are not included here, unless needed.
# class EventsController < Improver::BaseController
#
# Note: 2019-02-18
# Changing inheritance as the user_not_authorized method was not appropriate.
#
class EventsController < SpaController
  include WorkflowProps
  include ImproverTwoHelpers
  include NotificationMethods

  def index
    events = policy_scope(current_customer.events).includes(
      :actors, fieldable_values: %i[form_field entity]
    )

    @events = { events: events.map { |e| e.event_hashed(current_user) } }

    respond_to do |format|
      format.json do
        render json: @events
      end
    end
  end

  # For a new event, the front-end uses a rest endpoint (this one) and a
  # graphql endpoint. This endpoint provides the html layout and json of
  # involvable_users. The graphql provides all related data of the fieldable.
  def new
    respond_to do |format|
      format.json do
        render json: {
          involvable_responsibilities: possible_responsibilities(Event)
        }.as_json
      end
    end
  end

  def create
    @event = Event.new(event_params.merge(customer: current_customer))
    authorize @event

    # These methods are part of the module ImproverTwoHelpers.
    # This allows reuse in other controllers: @act and @audit.
    process_state(params["event"]["state"], @event)
    create_responsibilities(@event)
    process_fieldables(@event)
    new_internal_ref(@event)

    respond_to do |format|
      format.json do
        save_and_render(@event)
      end
    end

    # Notifications
    create_notice(@event) if @event.errors.blank?
  end

  # To edit an event, the front-end uses a rest endpoint (this one) and a
  # graphql endpoint. The rails rest edit endpoint is not used.
  #
  # This endpoint provides the html layout and json of involvable and involved
  # users, and fields not in form_field entity along with the possible
  # transitions including whether a comment is required for said transition.
  def show
    @event = current_customer.events.find(params[:id])
    @event.validate_all_fields

    authorize(@event)

    respond_to do |format|
      format.json do
        render json: { event: fields_entity(@event),
                       involvable_users: possible_responsibilities(Event),
                       errors: @event.errors.full_messages }
      end
    end
  end

  def update
    @event = current_customer.events.find(params[:id])
    @event.assign_attributes(event_params)

    process_fieldables(@event)

    respond_to do |format|
      format.html do
        render layout: "improver_modern"
      end
      format.json do
        save_and_render(@event)
      end
    end
    log_operation(@event) if @event.errors.blank?
  end

  def update_responsibilities
    @event = current_customer.events.find_by(id: params[:id])
    unless @event
      render json: {
        errors: { errors: ["There was no event to update role to."] }
      }, status: :bad_request # 400
      return
    end

    authorize(@event, "edit_roles?")
    process_responsibilities(@event)
    save_and_render(@event)

    return if @event.errors.present?

    log_operation(@event, "update")
    notify_update_responsibilities(@event)
  end

  # This method expects from the following from the front_end:
  # * the event_id,
  # * the desired transition,
  # * a comment, mandatory in certain circunstances.
  #
  def update_workflow
    @event = current_customer.events.find_by(id: params[:id])
    @comment = params["comment"]
    @transition = params["transition"]

    error_msgs = find_errors(@event)

    if error_msgs.any?
      render json: { errors: error_msgs }, status: :bad_request
      return
    end

    authorize(@event, "#{@transition}?")

    validator_response if @transition == "approve_action_plan"

    if @event.send(@transition)
      transition_notice(@event)
      render json: workflow_props(@event)
    else
      errors = @event.errors.full_messages
      render json: { errors: errors }.merge(workflow_props(@event)),
             status: :ok
    end
  end

  def destroy
    @event = current_customer.events.find(params[:id])
    authorize @event
    # TODO: Need to log the action for all the associated actions and audits?
    # Next line is needed to turn the ActiveRecord Assoc into an array and grab
    # the actions before the event is deleted.
    action_plan = @event.acts.to_a
    audits = @event.audits.to_a
    if @event.destroy
      # TODO: It is not clear what has to be done with the action plan.
      action_plan.each do |act|
        log_workflow(act, "The event, whom this action belonged to, was deleted.")
      end
      audits.each do |audit|
        log_workflow(audit, "The event belonging to this audit, was deleted.")
      end
      message = "Event has been deleted."
    else
      message = "An error occured while deleting the Event."
    end

    respond_to do |format|
      format.json do
        render json: { message: message, event: { title: @event.field_value_value("title") } }
        # TODO: eventually replace by @event.title after defining method
      end
    end
  end

  private

  def event_params
    params.require(:event).permit(
      fieldable_values_attributes: %i[
        id value form_field_id entity_id entity_type _destroy
      ]
    )
  end

  # This method adds the response of a validator. If the user is both cim and
  # validator, the response is filled for both.
  #
  # rubocop:disable Style/GuardClause: Use a guard clause
  # IMO, using a guard clause makes the code harder to read
  #
  def validator_response
    response_params = { response: true, response_at: Date.today }
    if @event.validators.include? current_user
      @event.event_validators
            .find_by(validator_id: current_user.id)
            .update(response_params)
    end
    if @event.continuous_improvement_managers.include? current_user
      @event.cims_responses
            .find_by(continuous_improvement_manager_id: current_user.id)
            .update(response_params)
    end
  end
  # rubocop:enable Style/GuardClause: Use a guard clause

  # Check if a comment is require given the transition name.
  def comment_required?(transition)
    comment_required_transitions = %w[force_close
                                      approve_force_close
                                      refuse_force_close
                                      refuse_action_plan
                                      refuse_closure
                                      back_to_analysis]
    comment_required_transitions.include?(transition)
  end
end
