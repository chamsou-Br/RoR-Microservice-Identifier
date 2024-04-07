# frozen_string_literal: true

class VerifiersController < ActorsController
  def authorize_multiple?
    true
  end

  def authorize_group?
    false
  end

  #
  # Is the given `user` a verifier of the given `wf_entity`?
  #
  # @param [Document, Graph] wf_entity
  # @param [User] user
  #
  # @return [Boolean]
  #
  def user_is_actor_of?(wf_entity, user)
    user.verifier_of?(wf_entity)
  end

  #
  # Add the given `user` as a verifier of the given `wf_entity`
  #
  # @param [Document, Graph] wf_entity
  # @param [User] user
  #
  # @return [void]
  #
  def push_user_to(wf_entity, user)
    wf_entity.verifiers.push(user)
  end

  #
  # Remove the given `user` from the list of verifiers of the given `wf_entity`
  #
  # @param [Document, Graph] wf_entity
  # @param [User] user
  #
  # @return [void]
  #
  def remove_user_from(wf_entity, user)
    wf_entity.delete_verifier(user)
  end

  #
  # Is the given `wf_entity` under verification?
  #
  # @param [Document, Graph] wf_entity
  #
  # @return [Boolean]
  #
  def wf_entity_in_accept_state?(wf_entity)
    wf_entity.in_verification?
  end

  #
  # Accepts the given `wf_entity` as the `user`
  #
  # @param [Document, Graph] wf_entity
  # @param [User] user
  #
  # @return [void]
  #
  def user_accept(wf_entity, user)
    comment = params[:comment]
    user.verify(wf_entity, true, comment)
  end

  #
  # Accepts the given `wf_entity` as an Administrator
  #
  # @param [Document, Graph] wf_entity to be accepted
  # @param [User] admin
  #
  # @return [void]
  #
  def admin_accept_instead_of(wf_entity, admin)
    # @type [User]
    user = current_customer.users.find params[:user_id]
    comment = "#{params[:comment]}."
    if admin != user
      case @wf_entity_type
      when "graph"
        msg = I18n.t("controllers.graphs.admin_verify.accepted_comment",
                     admin: admin.name.full,
                     user: user.name.full)
        comment += "\n#{msg}"
      when "document"
        msg = I18n.t("controllers.documents.admin_verify.accepted_comment",
                     admin: admin.name.full,
                     user: user.name.full)
        comment += "\n#{msg}"
      end
    end
    user.verify(wf_entity, true, comment, admin)
  end

  #
  # Rejects the given `wf_entity` as the `user`
  #
  # @param [Document, Graph] wf_entity
  # @param [User] user
  #
  # @return [void]
  #
  def user_reject(wf_entity, user)
    comment = params[:comment]
    user.verify(wf_entity, false, comment)
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
    comment = "#{params[:comment]}."
    if admin != user
      case @wf_entity_type
      when "graph"
        msg = I18n.t("controllers.graphs.admin_verify.rejected_comment",
                     admin: admin.name.full,
                     user: user.name.full)
        comment += "\n#{msg}"
      when "document"
        msg = I18n.t("controllers.documents.admin_verify.rejected_comment",
                     admin: admin.name.full,
                     user: user.name.full)
        comment += "\n#{msg}"
      end

    end
    user.verify(wf_entity, false, comment, admin)
  end

  #
  # A number of translated messages advising the user of changes or errors
  #
  # @param [Integer] count used when messages may be singular or plural
  #
  # @return [Hash{Symbol => String}]
  #
  def wording(count = 1)
    {
      user_is_pushed: I18n.t("controllers.verifiers.successes.user_is_pushed", count: count),
      user_is_removed: I18n.t("controllers.verifiers.successes.user_is_removed", count: count),
      user_accept: I18n.t("controllers.verifiers.successes.user_accept"),
      user_reject: I18n.t("controllers.verifiers.successes.user_reject"),
      user_accept_document: I18n.t("controllers.verifiers.successes.user_accept_document"),
      user_reject_document: I18n.t("controllers.verifiers.successes.user_reject_document"),
      user_is_actor: I18n.t("controllers.verifiers.errors.user_is_actor", count: count),
      user_not_actor: I18n.t("controllers.verifiers.errors.user_not_actor", count: count),
      user_is_actor_document: I18n.t("controllers.verifiers.errors.user_is_actor_document", count: count),
      user_not_actor_document: I18n.t("controllers.verifiers.errors.user_not_actor_document", count: count),
      user_not_pushed: I18n.t("controllers.verifiers.errors.user_not_pushed", count: count),
      user_not_removed: I18n.t("controllers.verifiers.errors.user_not_removed", count: count),
      user_not_accept: I18n.t("controllers.verifiers.errors.user_not_accept"),
      user_not_reject: I18n.t("controllers.verifiers.errors.user_not_reject"),
      user_not_accept_document: I18n.t("controllers.verifiers.errors.user_not_accept_document"),
      user_not_reject_document: I18n.t("controllers.verifiers.errors.user_not_reject_document"),
      graph_wrong_state: I18n.t("controllers.verifiers.errors.graph_wrong_state"),
      document_wrong_state: I18n.t("controllers.verifiers.errors.document_wrong_state")
    }
  end
end
