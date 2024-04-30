# frozen_string_literal: true

class TasksController < ApplicationController
  before_action :check_entity, except: :index

  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength
  def index
    @module = params[:module] || "all"
    @important = params[:important] || false
    @order = params[:order] || "desc"

    @tasks_groups = case @module
                    when "graph"
                      tasks_for_graph
                    when "document"
                      tasks_for_document
                    when "event"
                      tasks_for_event
                    when "audit"
                      tasks_for_audit
                    when "action"
                      tasks_for_act
                    when "improver"
                      tasks_for_improver
                    when "process"
                      tasks_for_process
                    else
                      tasks_for_all
                    end

    case @order
    when "asc"
      @tasks_groups.sort_by! { |a| a[:entity].task_date_for(a[:category]) }
    when "desc"
      @tasks_groups = @tasks_groups.sort_by { |a| a[:entity].task_date_for(a[:category]) }.reverse
    end

    respond_to do |format|
      format.html { render layout: false }
      format.js
    end
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength

  def set_important
    klass = params[:entity]
    id = params[:id]
    @category = params[:category]

    @entity = current_customer.send(klass.downcase.pluralize).find(id)

    task_flag = current_user.task_flags.find_by(taskable: @entity)

    if task_flag.nil?
      current_user.task_flags.create(taskable: @entity, important: true)
    else
      task_flag.update(important: true)
    end
  end

  def unset_important
    klass = params[:entity]
    id = params[:id]
    @category = params[:category]

    @entity = current_customer.send(klass.downcase.pluralize).find(id)

    task_flag = current_user.task_flags.find_by(taskable: @entity)

    task_flag&.update(important: false)
  end

  private

  def check_entity
    raise "method_not_allowed" unless TaskFlag.entity_markable?(params[:entity].downcase.pluralize)
  end

  # TODO: The following methods would be better placed as scopes or model class
  # methods of some kind
  # rubocop:disable Layout/LineLength, Metrics/AbcSize, Metrics/MethodLength
  def tasks_for_act
    tasks = []
    tasks += current_customer.acts.where(state: 0, owner: current_user)
                             .map { |item| { category: :acts_in_creation, entity: item } }
    tasks += current_customer.acts.where(state: 1, owner: current_user)
                             .map { |item| { category: :acts_in_progress, entity: item } }
    tasks += current_customer.acts.includes(:acts_validators)
                             .where(acts_validators: { validator: current_user })
                             .where(state: 2)
                             .map { |item| { category: :acts_pending_approval, entity: item } }
    tasks
  end

  def tasks_for_audit
    tasks = []
    tasks += current_customer.audits.where(state: 0, owner: current_user)
                             .map { |item| { category: :audits_planning, entity: item } }
    tasks += current_customer.audits.includes(audit_elements: :audit_participants)
                             .where("state = ? AND ((" \
                                    "audit_participants.participant_type = ? " \
                                    "AND audit_participants.participant_id = ? " \
                                    "AND audit_participants.auditor = ? ) " \
                                    "OR owner_id = ?)",
                                    Audit.states[:planned],
                                    "User",
                                    current_user.id,
                                    true,
                                    current_user.id)
                             .references(:audit_elements)
                             .map { |item| { category: :audits_planned, entity: item } }
    tasks += current_customer.audits.where("state = ? AND owner_id = ?",
                                           Audit.states[:in_progress],
                                           current_user.id)
                             .map { |item| { category: :audits_in_progress_owner, entity: item } }
    tasks += current_customer.audits.includes(audit_elements: :audit_participants)
                             .where("state = ? AND ((" \
                                    "audit_participants.participant_type = ? " \
                                    "AND audit_participants.participant_id = ? " \
                                    "AND audit_participants.auditor = ? ) )",
                                    Audit.states[:in_progress],
                                    "User",
                                    current_user.id,
                                    true)
                             .references(:audit_elements)
                             .map { |item| { category: :audits_in_progress_auditor, entity: item } }
    tasks += current_customer.audits.where(organizer: current_user, state: 3)
                             .map { |item| { category: :audits_pending_approval, entity: item } }

    tasks
  end

  # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  def tasks_for_document
    tasks = []
    tasks += current_customer.documents.where(author: current_user, state: "new")
                             .map { |item| { category: :documents_in_creation, entity: item } }
    tasks += current_customer.documents.includes(:documents_verifiers)
                             .where(documents_verifiers: { verifier: current_user,
                                                           historized: false,
                                                           verified: false },
                                    state: "verificationInProgress")
                             .map { |item| { category: :documents_in_verification, entity: item } }
    tasks += current_customer.documents.includes(:documents_approvers)
                             .where(documents_approvers: { approver: current_user,
                                                           historized: false,
                                                           approved: false },
                                    state: "approvalInProgress")
                             .map { |item| { category: :documents_in_approval, entity: item } }
    tasks += current_customer.documents.includes(:document_publisher)
                             .where(document_publishers: { publisher_id: current_user.id },
                                    state: "approved")
                             .map { |item| { category: :documents_publishing_in_progress, entity: item } }

    # task for documents read count_read_confirmations
    if current_customer.settings.approved_read_document?
      tasks += current_user.my_viewable_documents.includes(:read_confirmations)
                           .where(state: :applicable)
                           .select { |doc| doc.read_confirmations.blank? || !doc.read_confirmations.pluck(:user_id).include?(current_user.id) }
                           .map { |item| { category: :read_confirmation, entity: item } }
    end

    tasks
  end
  # rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

  def tasks_for_event
    tasks = []
    # This is a temporary change while we still double accounting. When actors
    # are fully implemented, this query will completely have to change.
    #
    tasks += current_customer.events.where(state: 0, owner_id: current_user.id)
                             .map { |item| { category: :events_under_analysis, entity: item } }
    tasks += current_customer.events.includes(:continuous_improvement_managers)
                             .where(state: 1,
                                    events_continuous_improvement_managers: {
                                      continuous_improvement_manager_id: current_user.id,
                                      response: nil
                                    })
                             .map { |item| { category: :events_pending_approval, entity: item } }
    tasks += current_customer.events.includes(:event_validators)
                             .where(state: 1, event_validators: { validator_id: current_user.id, response: nil })
                             .map { |item| { category: :events_pending_approval, entity: item } }
    tasks += current_customer.events.includes(:continuous_improvement_managers)
                             .where(state: 5,
                                    events_continuous_improvement_managers: {
                                      continuous_improvement_manager_id: current_user.id,
                                      response: nil
                                    })
                             .map { |item| { category: :events_pending_closure, entity: item } }
    tasks
  end

  # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  def tasks_for_graph
    tasks = []
    tasks += current_customer.graphs.where(author: current_user, state: "new")
                             .map { |item| { category: :graphs_in_creation, entity: item } }
    tasks += current_customer.graphs.includes(:graphs_verifiers)
                             .where(graphs_verifiers: { verifier: current_user, historized: false, verified: false },
                                    state: "verificationInProgress")
                             .map { |item| { category: :graphs_in_verification, entity: item } }
    tasks += current_customer.graphs.includes(:graphs_approvers)
                             .where(graphs_approvers: { approver: current_user, historized: false, approved: false },
                                    state: "approvalInProgress")
                             .map { |item| { category: :graphs_in_approval, entity: item } }
    tasks += current_customer.graphs.includes(:graph_publisher)
                             .where(graph_publishers: { publisher_id: current_user.id }, state: "approved")
                             .map { |item| { category: :graphs_publishing_in_progress, entity: item } }
    tasks += current_user.my_reviewable_graphs.map { |item| { category: :graph_review, entity: item.last_available } }

    if current_customer.settings.approved_read_graph?
      tasks += current_user.my_viewable_graphs.includes(:read_confirmations)
                           .where(state: :applicable)
                           .select { |graph| (graph.read_confirmations.blank? || !graph.read_confirmations.pluck(:user_id).include?(current_user.id)) && current_user.viewer_of?(graph) }
                           .map { |item| { category: :read_confirmation, entity: item } }
    end
    tasks
  end
  # rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  # rubocop:enable Layout/LineLength, Metrics/AbcSize, Metrics/MethodLength

  def tasks_for_all
    tasks_for_process + tasks_for_improver
  end

  def tasks_for_improver
    tasks_for_act + tasks_for_event + tasks_for_audit
  end

  def tasks_for_process
    tasks_for_graph + tasks_for_document
  end
end
