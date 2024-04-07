# frozen_string_literal: true

class ApproversController < ActorsController
  def authorize_multiple?
    true
  end

  def authorize_group?
    false
  end

  def user_is_actor_of?(wf_entity, user)
    user.approver_of?(wf_entity)
  end

  def push_user_to(wf_entity, user)
    wf_entity.approvers.push(user)
  end

  def remove_user_from(wf_entity, user)
    wf_entity.delete_approver(user)
  end

  def wf_entity_in_accept_state?(wf_entity)
    wf_entity.in_approval?
  end

  def user_accept(wf_entity, user)
    comment = params[:comment]
    user.approve(wf_entity, true, comment)
  end

  def user_reject(wf_entity, user)
    comment = params[:comment]
    user.approve(wf_entity, false, comment)
  end

  #
  # Approves the given `wf_entity` as an Administrator
  #
  # @param [Document, Graph] wf_entity to be approved
  # @param [User] admin
  #
  # @return [void]
  #
  def admin_accept_instead_of(wf_entity, admin)
    # @type [User]
    user = current_customer.users.find params[:user_id]
    wf_entity_type = wf_entity.instance_of?(Document) ? "documents" : "graphs"
    comment = "#{params[:comment]}."
    if admin != user
      # i18n-tasks-use t('controllers.documents.admin_approve.accepted_comment')
      # i18n-tasks-use t('controllers.graphs.admin_approve.accepted_comment')
      msg = I18n.t("controllers.#{wf_entity_type}.admin_approve.accepted_comment",
                   admin: admin.name.full,
                   user: user.name.full)
      comment += "\n#{msg}"
    end
    user.approve(wf_entity, true, comment, admin)
  end

  #
  # Rejects the given `wf_entity` as an Administrator
  #
  # @param [Document, Graph] wf_entity to be rejected
  # @param [User] admin
  #
  # @return [void]
  #
  def admin_reject_instead_of(wf_entity, admin)
    # @type [User]
    user = current_customer.users.find params[:user_id]
    wf_entity_type = wf_entity.instance_of?(Document) ? "documents" : "graphs"
    comment = "#{params[:comment]}."
    if admin != user
      # i18n-tasks-use t('controllers.documents.admin_approve.rejected_comment')
      # i18n-tasks-use t('controllers.graphs.admin_approve.rejected_comment')
      msg = I18n.t("controllers.#{wf_entity_type}.admin_approve.rejected_comment",
                   admin: admin.name.full,
                   user: user.name.full)
      comment += "\n#{msg}"
    end
    user.approve(wf_entity, false, comment, admin)
  end

  def wording(count = 1)
    {
      user_is_pushed: I18n.t("controllers.approvers.successes.user_is_pushed", count: count),
      user_is_removed: I18n.t("controllers.approvers.successes.user_is_removed", count: count),
      user_accept: I18n.t("controllers.approvers.successes.user_accept"),
      user_reject: I18n.t("controllers.approvers.successes.user_reject"),
      user_accept_document: I18n.t("controllers.approvers.successes.user_accept_document"),
      user_reject_document: I18n.t("controllers.approvers.successes.user_reject_document"),
      user_is_actor: I18n.t("controllers.approvers.errors.user_is_actor", count: count),
      user_not_actor: I18n.t("controllers.approvers.errors.user_not_actor", count: count),
      user_is_actor_document: I18n.t("controllers.approvers.errors.user_is_actor_document", count: count),
      user_not_actor_document: I18n.t("controllers.approvers.errors.user_not_actor_document", count: count),
      user_not_pushed: I18n.t("controllers.approvers.errors.user_not_pushed", count: count),
      user_not_removed: I18n.t("controllers.approvers.errors.user_not_removed", count: count),
      user_not_accept: I18n.t("controllers.approvers.errors.user_not_accept"),
      user_not_reject: I18n.t("controllers.approvers.errors.user_not_reject"),
      user_not_accept_document: I18n.t("controllers.approvers.errors.user_not_accept_document"),
      user_not_reject_document: I18n.t("controllers.approvers.errors.user_not_reject_document"),
      graph_wrong_state: I18n.t("controllers.approvers.errors.graph_wrong_state"),
      document_wrong_state: I18n.t("controllers.approvers.errors.document_wrong_state")
    }
  end
end
