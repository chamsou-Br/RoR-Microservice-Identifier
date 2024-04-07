# frozen_string_literal: true

class PublisherController < ActorsController
  def authorize_multiple?
    false
  end

  def authorize_group?
    false
  end

  def user_is_actor_of?(wf_entity, user)
    user.publisher_of?(wf_entity)
  end

  def wf_entity_in_accept_state?(wf_entity)
    wf_entity.in_publication? || wf_entity.in_scheduled_publication?
  end

  def user_accept(wf_entity, _user)
    date = parse_iso8601 params[:date]
    ten_seconds = ENV.fetch("PYX4_DEBUG_PUBLISHING", false) && params[:ten_seconds] == "true"
    logger.debug "publish in 10 seconds? #{ten_seconds ? 'yes' : 'no'}"
    date = 10.seconds.from_now if ten_seconds
    key = wf_entity.instance_of?(Document) ? "user_accept_document" : "user_accept"
    if date.nil?
      @wording_user_accept = I18n.t("controllers.publisher.successes.#{key}.now")
      wf_entity.publish
    elsif date > Time.now
      @wording_user_accept = I18n.t("controllers.publisher.successes.#{key}.delayed")
      wf_entity.publish_on(date)
    else
      false
    end
  end

  #
  # Publishes or schedules the publishing of the given `wf_entity` as an
  # Administrator.
  #
  # @param [Document, Graph] wf_entity to publish or be published
  # @param [User] admin
  #
  # @return [Boolean] `true` if the entity has been published or scheduled for
  #   publishing or `false` otherwise
  #
  def admin_accept_instead_of(wf_entity, admin)
    date = parse_iso8601 params[:date]
    # @type [User]
    user = current_customer.users.find params[:user_id]
    user_key = wf_entity.instance_of?(Document) ? "user_accept_document" : "user_accept"
    admin_key = wf_entity.instance_of?(Document) ? "admin_accept_document" : "admin_accept"
    if date.nil?
      @wording_user_accept = if admin == user
                               I18n.t("controllers.publisher.successes.#{user_key}.now")
                             else
                               I18n.t("controllers.publisher.successes.#{admin_key}.now", user: user.name.full)
                             end
      wf_entity.publish(admin)
    elsif date > Time.now
      @wording_user_accept = I18n.t("controllers.publisher.successes.#{admin_key}.delayed")
      wf_entity.publish_on(date)
    else
      false
    end
  end

  def create
    @old_user = @wf_entity.publisher
    if @user.process_admin?
      @wf_entity.update(publisher: @user)
      flash_x_success wording[:user_is_pushed]
    else
      head :method_not_allowed
    end
  end

  def destroy
    @wf_entity.publisher = nil
    flash_x_success wording[:user_is_removed]
  end

  def wording(_count = 1)
    {
      user_is_pushed: I18n.t("controllers.publisher.successes.user_is_pushed"),
      user_is_removed: I18n.t("controllers.publisher.successes.user_is_removed"),
      user_is_actor: I18n.t("controllers.publisher.errors.user_is_actor"),
      user_not_actor: I18n.t("controllers.publisher.errors.user_not_actor"),
      user_is_actor_document: I18n.t("controllers.publisher.errors.user_is_actor_document"),
      user_not_actor_document: I18n.t("controllers.publisher.errors.user_not_actor_document"),
      user_not_pushed: I18n.t("controllers.publisher.errors.user_not_pushed"),
      user_not_removed: I18n.t("controllers.publisher.errors.user_not_removed"),
      user_accept: @wording_user_accept,
      user_not_accept: I18n.t("controllers.publisher.errors.user_not_accept"),
      graph_wrong_state: I18n.t("controllers.publisher.errors.graph_wrong_state"),
      document_wrong_state: I18n.t("controllers.publisher.errors.document_wrong_state")
    }
  end
end
