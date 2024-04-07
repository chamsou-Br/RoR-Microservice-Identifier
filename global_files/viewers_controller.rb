# frozen_string_literal: true

class ViewersController < ActorsController
  def authorize_multiple?
    true
  end

  def authorize_group?
    true
  end

  def authorize_role?
    true
  end

  def user_is_actor_of?(wf_entity, user)
    user.viewer_of?(wf_entity)
  end

  def group_is_actor_of?(wf_entity, group)
    group.viewer_of?(wf_entity)
  end

  def push_user_to(wf_entity, user)
    wf_entity.viewers.push(user)
  end

  def remove_user_from(wf_entity, user)
    wf_entity.viewers.destroy(user.id)
  end

  def push_group_to(wf_entity, group)
    wf_entity.viewergroups.push(group)
  end

  def remove_group_from(wf_entity, group)
    wf_entity.viewergroups.destroy(group.id)
  end

  def push_role_to(wf_entity, role)
    wf_entity.viewerroles.push(role)
  end

  def remove_role_from(wf_entity, role)
    wf_entity.viewerroles.destroy(role.id)
  end

  # rubocop:disable Metrics/AbcSize, Metrics/PerceivedComplexity
  def create_role
    @role = current_customer.roles.find(params[:id])

    if authorize_role? && !@role.viewer_of?(@wf_entity)
      if @wf_entity.is_a?(Graph) &&
         @wf_entity.linked_internal_roles.include?(@role) &&
         !@wf_entity.groupgraph.auto_role_viewer
        flash_x_error wording[:role_not_pushed_internal], :method_not_allowed
      elsif push_role_to(@wf_entity, @role)
        flash_x_success wording[:role_is_pushed]
      else
        flash_x_error wording[:role_not_pushed], :internal_server_error
      end
    else
      flash_x_error wording[:"role_is_actor_of_#{@wf_entity.class.name.downcase}"], :method_not_allowed
    end
  end

  def destroy_role
    @role = current_customer.roles.find(params[:id])

    if authorize_role? && @role.viewer_of?(@wf_entity)
      if @wf_entity.is_a?(Graph) &&
         @wf_entity.linked_internal_roles.include?(@role) &&
         @wf_entity.groupgraph.auto_role_viewer
        flash_x_error wording[:role_not_removed_internal], :method_not_allowed
      elsif remove_role_from(@wf_entity, @role)
        flash_x_success wording[:role_is_removed]
      else
        flash_x_error wording[:role_not_removed], :internal_server_error
      end
    else
      flash_x_error wording[:"role_not_actor_of_#{@wf_entity.class.name.downcase}"], :method_not_allowed
    end
  end
  # rubocop:enable Metrics/AbcSize, Metrics/PerceivedComplexity

  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  def wording(count = 1)
    {
      user_is_pushed: I18n.t("controllers.viewers.successes.user_is_pushed", count: count),
      group_is_pushed: I18n.t("controllers.viewers.successes.group_is_pushed"),
      role_is_pushed: I18n.t("controllers.viewers.successes.role_is_pushed"),
      user_is_removed: I18n.t("controllers.viewers.successes.user_is_removed", count: count),
      group_is_removed: I18n.t("controllers.viewers.successes.group_is_removed"),
      role_is_removed: I18n.t("controllers.viewers.successes.role_is_removed"),
      user_is_actor_of_graph: I18n.t("controllers.viewers.errors.user_is_actor_of_graph", count: count),
      user_not_actor_of_graph: I18n.t("controllers.viewers.errors.user_not_actor_of_graph", count: count),
      user_is_actor_of_document: I18n.t("controllers.viewers.errors.user_is_actor_of_document", count: count),
      user_not_actor_of_document: I18n.t("controllers.viewers.errors.user_not_actor_of_document", count: count),
      group_is_actor_of_graph: I18n.t("controllers.viewers.errors.group_is_actor_of_graph"),
      group_not_actor_of_graph: I18n.t("controllers.viewers.errors.group_not_actor_of_graph"),
      role_is_actor_of_graph: I18n.t("controllers.viewers.errors.role_is_actor_of_graph"),
      role_not_actor_of_graph: I18n.t("controllers.viewers.errors.role_not_actor_of_graph"),
      role_is_actor_of_document: I18n.t("controllers.viewers.errors.role_is_actor_of_document"),
      role_not_actor_of_document: I18n.t("controllers.viewers.errors.role_not_actor_of_document"),
      group_is_actor_of_document: I18n.t("controllers.viewers.errors.group_is_actor_of_document"),
      group_not_actor_of_document: I18n.t("controllers.viewers.errors.group_not_actor_of_document"),
      user_not_pushed: I18n.t("controllers.viewers.errors.user_not_pushed", count: count),
      group_not_pushed: I18n.t("controllers.viewers.errors.group_not_pushed"),
      role_not_pushed: I18n.t("controllers.viewers.errors.role_not_pushed"),
      user_not_removed: I18n.t("controllers.viewers.errors.user_not_removed", count: count),
      group_not_removed: I18n.t("controllers.viewers.errors.group_not_removed"),
      role_not_removed: I18n.t("controllers.viewers.errors.role_not_removed"),
      role_not_pushed_internal: I18n.t("controllers.viewers.errors.role_not_pushed_internal"),
      role_not_removed_internal: I18n.t("controllers.viewers.errors.role_not_removed_internal")
    }
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength
end
