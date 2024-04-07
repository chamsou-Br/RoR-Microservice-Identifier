# frozen_string_literal: true

# TODO: Remove unused or unimplemented methods
# This class has many methods which are unimplemented or simply return `false`
# which is equivalent given their purpose (assumed from their name and params).
# - authorize_multiple?
# - authorize_group?
# - authorize_role?
# - user_is_actor_of?
# - group_is_actor_of?
# - wf_entity_in_accept_state?
# - push_user_to
# - remove_user_from
# - push_group_to
# - remove_group_from
# - user_accept
# - user_reject
# - admin_accept_instead_of
# - admin_approve_instead_of
# - admin_reject_instead_of
# - admin_disapprove_instead_of
# These seem likely to be technical debt of which we must be rid.  We must
# ensure they are not being called or relied upon by some meta-programming hack.
#
# TODO: there is no direct route to this controller. It might not be used at
# all unless it is called from the graph or document controller.
class ActorsController < ApplicationController
  before_action :find_wf_entity

  before_action :require_wf_entity_in_edition,
                except: %i[accept admin_accept reject admin_reject
                           admin_approve admin_disapprove]

  before_action :check_authorize_multiple,
                :find_users,
                except: %i[create_group destroy_group create_role destroy_role]

  before_action :check_authorize_group,
                :find_group,
                only: %i[create_group destroy_group]

  before_action :filter_users_not_actors, only: [:create]

  before_action :require_group_not_actor, only: [:create_group]

  before_action :filter_users_are_actors, only: %i[destroy accept reject]

  before_action :require_group_is_actor, only: [:destroy_group]

  before_action :require_wf_entity_in_accept_state,
                :require_user_is_current,
                only: %i[accept reject admin_accept admin_reject admin_approve
                         admin_disapprove]

  before_action :require_current_user_is_admin,
                only: %i[admin_accept admin_reject admin_approve
                         admin_disapprove]

  # Whether authorize multiple pushes/removals of actors with one request
  def authorize_multiple?
    false
  end

  # Whether authorize pushes/removals of actor groups
  def authorize_group?
    false
  end

  def authorize_role?
    false
  end

  # Whether a user is actor of a wf_entity
  def user_is_actor_of?(_wf_entity, _user)
    false
  end

  # Whether a group of users is actor of a wf_entity
  def group_is_actor_of?(_wf_entity, _group)
    false
  end

  # Whether a wf_entity has the correct state to be accepted or rejected
  def wf_entity_in_accept_state?(_wf_entity)
    false
  end

  # Push a user to the list of the graph's actors
  def push_user_to(_graph, _user)
    false
  end

  # Remove a user from the list of the wf_entity's actors
  def remove_user_from(_wf_entity, _user)
    false
  end

  # Push a group of users to the list of the graph's actor groups
  def push_group_to(_graph, _group)
    false
  end

  # Remove a group of users from the list of the graph's actor groups
  def remove_group_from(_graph, _group)
    false
  end

  # A user accepts the graph
  def user_accept(_graph, _user); end

  # A user rejects the graph
  def user_reject(_graph, _user); end

  def admin_accept_instead_of(_graph, _admin); end

  def admin_approve_instead_of(_graph, _admin); end

  def admin_reject_instead_of(_graph, _admin); end

  def admin_disapprove_instead_of(_graph, _admin); end

  # Flash messages sent back through the request using X headers
  # TODO: Remove unused `count` parameter
  # rubocop:disable Metrics/MethodLength
  def wording(_count = 1)
    {
      user_is_actor_of_graph: "", # the passed user is already an actor of the graph
      user_not_actor_of_graph: "", # the passed user in not an actor of the graph
      user_is_actor_of_document: "", # the passed user is already an actor of the document
      user_not_actor_of_document: "", # the passed user in not an actor of the document
      group_is_actor_of_graph: "", # the passed group of users is already an actor of the graph
      group_not_actor_of_graph: "", # the passed group of users is not an actor of the graph
      group_is_actor_of_document: "", # the passed group of users is already an actor of the document
      group_not_actor_of_document: "", # the passed group of users is not an actor of the document
      graph_wrong_state: "", # the graph has not the required state to be accepted or rejected
      document_wrong_state: "", # the document has not the required state to be accepted or rejected
      only_one_user: "", # only one user at a time can accept or reject the graph
      user_not_current: "", # only the current user can accept or reject the graph
      user_is_pushed: "", # successfully pushed one user to the list of the graph's actors
      user_not_pushed: "", # failed to pushed one user to the list of the graph's actors
      group_is_pushed: "", # successfully pushed a group of users to the list of the graph's actor groups
      group_not_pushed: "", # failed to pushed a group of users to the list of the graph's actor groups
      user_is_removed: "", # successfully removed one user from the list of the graph's actors
      user_not_removed: "", # failed to removed one user from the list of the graph's actors
      group_is_removed: "", # successfully removed a group of users from the list of the graph's actor groups
      group_not_removed: "" # failed to removed a group of users from the list of the graph's actor groups
    }
  end
  # rubocop:enable Metrics/MethodLength

  # TODO: Untangled this horror of nested ifs
  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  def create
    if authorize_multiple? && @users.count > 1
      pushed = []
      @users.each { |user| pushed << user if push_user_to(@wf_entity, user) }
      if pushed.count == @users.count
        flash_x_success wording(@users.count)[:user_is_pushed]
      else
        pushed.each { |user| remove_user_from(@wf_entity, user) }
        flash_x_error wording(@users.count)[:user_not_pushed],
                      :internal_server_error
      end
    elsif @users.count == 1
      if push_user_to(@wf_entity, @users[0])
        flash_x_success wording[:user_is_pushed]
      else
        flash_x_error wording[:user_not_pushed], :internal_server_error
      end
    end
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

  def create_group
    return unless authorize_group? && @group.present?

    if push_group_to(@wf_entity, @group)
      flash_x_success wording[:group_is_pushed]
    else
      flash_x_error wording[:group_not_pushed], :internal_server_error
    end
  end

  # TODO: Untangled this horror of nested ifs
  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  def destroy
    if authorize_multiple? && @users.count > 1
      removed = []
      @users.each do |user|
        removed << user if remove_user_from(@wf_entity, user)
      end
      if removed.count == @users.count
        flash_x_success wording(@users.count)[:user_is_removed]
      else
        removed.each { |user| push_user_to(@wf_entity, user) }
        flash_x_error wording(@users.count)[:user_not_removed],
                      :internal_server_error
      end
    elsif @users.count == 1
      if remove_user_from(@wf_entity, @users[0])
        flash_x_success wording[:user_is_removed]
      else
        flash_x_error wording[:user_not_removed], :internal_server_error
      end
    end
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

  def destroy_group
    return unless authorize_group? && !@group.nil?

    if remove_group_from(@wf_entity, @group)
      flash_x_success wording[:group_is_removed]
    else
      flash_x_error wording[:group_not_removed], :internal_server_error
    end
  end

  # rubocop:disable Metrics/MethodLength
  def accept
    unless user_accept(@wf_entity, @users[0])
      flash_msg = @wf_entity_type == "document" ? :user_not_accept_document : :user_not_accept
      return flash_x_error wording[flash_msg], :internal_server_error
    end

    flash_msg = @wf_entity_type == "document" ? :user_accept_document : :user_accept
    flash_x_success wording[flash_msg]
    respond_to do |format|
      format.js do
        case @wf_entity_type
        when "graph"
          @partial = "graphs/states/#{wf_entity_state_to_partial(@wf_entity)}"
          render template: "graphs/state_change"
        when "document"
          @partial = "documents/states/#{wf_entity_state_to_partial(@wf_entity)}"
          render template: "documents/state_change"
        end
      end
      # When called as html, it is assumed that it is not called as part of a
      # partial, and displaying the dashboard again is reasonable. This happens
      # when some of the workflow is advanced directly from the task manager
      # via a magic button. Specifically this is triggered by direct links
      # using `button_to` in `app/helpers/tasks_helper.rb`. #2985 has the
      # details as well as the MR where changed were made.
      #
      format.html do
        redirect_to :dashboard_index
      end
    end
  end
  # rubocop:enable Metrics/MethodLength

  def admin_accept
    if admin_accept_instead_of(@wf_entity, @users[0])
      flash_msg = @wf_entity_type == "document" ? :user_accept_document : :user_accept
      flash_x_success wording[flash_msg]
      root_location = @wf_entity.instance_of?(Document) ? "documents" : "graphs"
      respond_to do |format|
        format.js do
          @partial = "#{root_location}/states/#{wf_entity_state_to_partial(@wf_entity)}"
          render template: "#{root_location}/state_change"
        end
      end
    else
      flash_msg = @wf_entity_type == "document" ? :user_not_accept_document : :user_not_accept
      flash_x_error wording[flash_msg], :internal_server_error
    end
  end

  def admin_approve
    if admin_approve_instead_of(@wf_entity, @users[0])
      flash_msg = @wf_entity_type == "document" ? :user_accept_document : :user_accept
      flash_x_success wording[flash_msg]
      respond_to do |format|
        format.js do
          @partial = "graphs/states/#{wf_entity_state_to_partial(@wf_entity)}"
          render template: "graphs/state_change"
        end
      end
    else
      flash_msg = @wf_entity_type == "document" ? :user_not_accept_document : :user_not_accept
      flash_x_error wording[flash_msg], :internal_server_error
    end
  end

  def reject
    if user_reject(@wf_entity, @users[0])
      flash_msg = @wf_entity_type == "document" ? :user_reject_document : :user_reject
      flash_x_success wording[flash_msg]
      respond_to do |format|
        format.js do
          case @wf_entity_type
          when "graph"
            @partial = "graphs/states/#{wf_entity_state_to_partial(@wf_entity)}"
            render template: "graphs/state_change"
          when "document"
            @partial = "documents/states/#{wf_entity_state_to_partial(@wf_entity)}"
            render template: "documents/state_change"
          end
        end
      end
    else
      flash_msg = @wf_entity_type == "document" ? :user_not_reject_document : :user_not_reject
      flash_x_error wording[flash_msg], :internal_server_error
    end
  end

  def admin_reject
    if admin_reject_instead_of(@wf_entity, @users[0])
      flash_msg = @wf_entity_type == "document" ? :user_reject_document : :user_reject
      flash_x_success wording[flash_msg]
      root_location = @wf_entity.instance_of?(Document) ? "documents" : "graphs"
      respond_to do |format|
        format.js do
          @partial = "#{root_location}/states/#{wf_entity_state_to_partial(@wf_entity)}"
          render template: "#{root_location}/state_change"
        end
      end
    else
      flash_msg = @wf_entity_type == "document" ? :user_not_reject_document : :user_not_reject
      flash_x_error wording[flash_msg], :internal_server_error
    end
  end

  def admin_disapprove
    if admin_disapprove_instead_of(@wf_entity, @users[0])
      flash_msg = @wf_entity_type == "document" ? :user_reject_document : :user_reject
      flash_x_success wording[flash_msg]
      respond_to do |format|
        format.js do
          @partial = "graphs/states/#{wf_entity_state_to_partial(@wf_entity)}"
          render template: "graphs/state_change"
        end
      end
    else
      flash_msg = @wf_entity_type == "document" ? :user_not_reject_document : :user_not_reject
      flash_x_error wording[flash_msg], :internal_server_error
    end
  end

  private

  def find_wf_entity
    if params[:graph_id].present?
      @wf_entity = current_customer.graphs.find_by(id: params[:graph_id])
      @wf_entity_type = "graph"
    elsif params[:document_id].present?
      @wf_entity = current_customer.documents.find_by(id: params[:document_id])
      @wf_entity_type = "document"
    end

    return if @wf_entity.present?

    case @wf_entity_type
    when "graph"
      flash_x_error I18n.t("controllers.actors.errors.find_graph"), :not_found
    when "document"
      flash_x_error I18n.t("controllers.actors.errors.find_document"),
                    :not_found
    end
  end

  def require_wf_entity_in_edition
    return if @wf_entity.in_edition?

    case @wf_entity_type
    when "graph"
      flash_x_error I18n.t("controllers.actors.errors.require_graph_in_edition"),
                    :method_not_allowed
    when "document"
      flash_x_error I18n.t("controllers.actors.errors.require_document_in_edition"),
                    :method_not_allowed
    end
  end

  def check_authorize_multiple
    @ids = params[:id].split(/\s*,\s*/).uniq
    return unless @ids.count > 1 && !authorize_multiple?

    flash_x_error I18n.t("controllers.actors.errors.check_authorize_multiple"),
                  :forbidden
  end

  def find_users
    @users = []
    if authorize_multiple? && @ids.count > 1
      @ids.each do |id|
        @users << current_customer.users.find_by(id: id)
        if @users.last.nil?
          return flash_x_error I18n.t("controllers.actors.errors.find_users.other"),
                               :not_found
        end
      end
    else
      @user = @users[0] = current_customer.users.find_by(id: @ids[0])
      if @users[0].nil?
        flash_x_error I18n.t("controllers.actors.errors.find_users.one"),
                      :not_found
      end
    end
  end

  def check_authorize_group
    return unless params[:id].present? && !authorize_group?

    flash_x_error I18n.t("controllers.actors.errors.check_authorize_group"),
                  :forbidden
  end

  def find_group
    @group = current_customer.groups.find_by(id: params[:id])
    # rubocop:disable Style/GuardClause
    if @group.nil?
      flash_x_error I18n.t("controllers.actors.errors.find_group"),
                    :not_found
    end
    # rubocop:enable Style/GuardClause
  end

  def filter_users_not_actors
    count = @users.count
    @users.delete_if { |user| user_is_actor_of?(@wf_entity, user) }

    return unless @users.count.zero?

    case @wf_entity_type
    when "graph"
      flash_x_error wording(count)[:user_is_actor_of_graph], :method_not_allowed
    when "document"
      flash_x_error wording(count)[:user_is_actor_of_document],
                    :method_not_allowed
    end
  end

  def require_group_not_actor
    return unless authorize_group? && group_is_actor_of?(@wf_entity, @group)

    case @wf_entity_type
    when "graph"
      flash_x_error wording[:group_is_actor_of_graph], :method_not_allowed
    when "document"
      flash_x_error wording[:group_is_actor_of_document], :method_not_allowed
    end
  end

  def require_group_is_actor
    return unless authorize_group? && !group_is_actor_of?(@wf_entity, @group)

    case @wf_entity_type
    when "graph"
      flash_x_error wording[:group_not_actor_of_graph], :method_not_allowed
    when "document"
      flash_x_error wording[:group_not_actor_of_document], :method_not_allowed
    end
  end

  def filter_users_are_actors
    count = @users.count
    @users.delete_if { |user| !user_is_actor_of?(@wf_entity, user) }

    return unless @users.count.zero?

    case @wf_entity_type
    when "graph"
      flash_x_error wording(count)[:user_not_actor_of_graph],
                    :method_not_allowed
    when "document"
      flash_x_error wording(count)[:user_not_actor_of_document],
                    :method_not_allowed
    end
  end

  def require_wf_entity_in_accept_state
    case @wf_entity_type
    when "graph"
      unless wf_entity_in_accept_state?(@wf_entity)
        flash_x_error wording[:graph_wrong_state],
                      :method_not_allowed
      end
    when "document"
      unless wf_entity_in_accept_state?(@wf_entity)
        flash_x_error wording[:document_wrong_state],
                      :method_not_allowed
      end
    end
  end

  def require_user_is_current
    unless @users.count == 1
      flash_x_error I18n.t("controllers.actors.errors.only_one_user"),
                    :method_not_allowed
    end

    return if @users[0] == current_user

    flash_x_error I18n.t("controllers.actors.errors.user_not_current"),
                  :method_not_allowed
  end

  def require_current_user_is_admin
    current_user.process_admin?
  end
end
