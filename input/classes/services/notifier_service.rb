# frozen_string_literal: true

# The class is responsible centralizing all notificiations and perhaps logging
# in the app.
class NotifierService
  include EventNotifications
  include ActionNotifications
  include AuditNotifications

  def initialize(entity:, user:, transition: nil, comment: "", operation: nil)
    @entity = entity
    @transition = transition
    @operation = operation
    @user = user
    @comment = comment
  end

  def create_notice
    send("#{@entity.class.to_s.underscore}_create_notice")
  end

  # A transition notice method in in charge of sending specific notices to
  # specific responsibilities, depending on the transition and the entity.
  # It will:
  # * call log_workflow to log the transition in the entitty timeline
  # * call notify_by_role as many times as needed depending on the transiton.
  #
  def transition_notice
    send("#{@entity.class.to_s.underscore}_#{@transition}")
  end

  # Logs a workflow entry in the `timeline_items` for `entity` for @user,
  # with optional `comment`. The method does not check for object changes,
  # it will log the transision and the state of the entity, as it is called
  # after a successful state change. Here we move away from 'object dirty' as
  # the state machine may update entity again in an `after_transition` block.
  #
  def log_workflow(entity = @entity, comment = @comment, operation = "workflow")
    entity.timeline_items.create author: @user,
                                 object: { state: entity.state,
                                           transition: @transition }.to_json,
                                 action: operation,
                                 comment: comment
  end

  ## `log_operation` and `log_workflow` are essentiallly the same, one saves
  # any operation (as implemented originally) and the second assigns "workflow"
  # to operation, to identify the transitons from any other entity's changes.
  #
  # TODO: `log_operation` might in the future be combines with `log_workflow`.
  # In certain places of the appication, `log_action` (the predecesor of
  # `log_operation` is still being used. Refer to than method for previous
  # implementation details.
  #
  # Logs an entry for 'operation' in the 'timeline_items' for 'entity' having
  # @user as 'author', with optional 'comment'. when:
  # * entity attributes have `#saved_changes`, or
  # * associations were changed (I do not think this is verified), or
  # * any of the fieldable_values have changed according to `#saved_changes`.
  #
  def log_operation(entity = @entity, operation = @operation,
                    comment = @comment)
    hash_fieldables = filter_fieldables(entity)
    hash_attributes = filter_attributes(entity)

    # This merge ensures that only one key is passed in the context.
    filtered_hash = hash_fieldables.merge(hash_attributes)
    return unless filtered_hash.any?

    # Following from this note's merge
    # (https://gitlab.qualiproto.fr/pyx4/qualipso/merge_requests/2146#note_54283)
    # the sparse flag represents the density of the record according to the
    # mathematical definition of sparse matrix, in which most elements are
    # zero. This was the previous way of storing timeline operations, as
    # oppossed to now, where only the changes are logged.
    #
    entity.timeline_items.create author: @user,
                                 object: filtered_hash.to_json,
                                 action: operation,
                                 sparse: false,
                                 comment: comment

    # reload clears the hash of dirty form_fields of fieldable_values
    entity.reload
  end

  # This method builds a (key, value) pairs hash, each pair representing each
  # fieldable_value that changed.
  #
  def filter_fieldables(entity)
    field_values = entity.fieldable_values
    fields_to_track = entity.fields_to_track
    field_names_to_track = fields_to_track.keys

    entity.dirty_fields.each_with_object({}) do |field, result|
      field_name_sym = field.field_name.to_sym
      next unless field_names_to_track.include?(field_name_sym)

      key_name = fields_to_track[field_name_sym]

      case field.field_type.to_sym
      when :single_select, :multi_select, :uni_linkable, :multi_linkable
        ids = field_values.where(form_field: field).pluck(:entity_id)
        result[key_name] = ids
      else
        result[key_name] = field.field_values.first.value
      end
    end
  end

  # This method builds a (key, value) pairs hash with the model fields changed.
  # rubocop:disable Metrics/AbcSize
  # TODO: refactor to enable cop. Perhaps when able to delete
  # entity.many_associations_to_track
  #
  def filter_attributes(entity)
    # ActiveModel#saved_changes:
    # Returns a hash of attributes that were changed before the model was saved.
    #
    # Calculate the attributes that changed
    attrs_changed = entity.saved_changes.keys +
                    entity.dirty_attributes.map(&:to_s)

    # Find the attributes included in the tracktable attributes and methods.
    tracking = entity.attributes_to_track +
               entity.many_associations_to_track +
               entity.actors_to_track +
               entity.actor_to_track
    attrs_to_log = tracking & attrs_changed

    # Create the hash to store, following the current format. In the future
    # this log should include a before and after value.
    attrs_to_log.each_with_object({}) do |a, result|
      if entity.actor_to_track.include?(a)
        result["#{a}_id"] = entity.send(a).id
      elsif entity.actors_to_track.include?(a)
        result["#{a}_ids"] = entity.send("#{a}s").pluck(:id)
      else
        result[a] = entity.send(a)
      end
    end
  end
  # rubocop:enable Metrics/AbcSize

  def notify_update_responsibilities(responsibilities_changed)
    category = "#{@entity.class.to_s.downcase}_assignment".to_sym
    user_ids = responsibilities_changed.map(&:last).flatten.uniq
    recipients = User.find(user_ids)
    email_and_notif_for(recipients, @entity, category)
  end

  #
  # Destroys Store connection notifications for the given `@user` if the related
  # entity does not exist.
  #
  def destroy_invalid_notifications
    notifications = NewNotification.where(
      to: @user, category: %w[connection_request connection_established]
    )
    return if notifications.empty?

    notifications.each { |n| n.destroy! if n.entity.nil? }
  end

  private

  def notify_by_role(entity, category, *responsibilities)
    all_users = []
    responsibilities.each do |responsibility|
      case responsibility
      when /(author)/, /(organizer)/, /^(owner)$/
        all_users << entity.send(responsibility.to_s)
      when /(validator)/, /(contributor)/, /(domain_owner)/,
        /(auditor)/, /(auditee)/
        all_users += entity.send("#{responsibility}s")
      when "cim"
        # all_users += entity.continuous_improvement_managers
        all_users += entity.cims
      end
    end

    recipients = (all_users - [@user]).uniq
    email_and_notif_for(recipients, entity, category)
  end

  def notifs_audits_autoclose(entity)
    # Notify the audit which would have been autoclosed by closing the event.
    entity.audits.each do |audit|
      # Only send a notification if the audit was closed today.
      next unless audit.closed? && audit.real_closed_at == Date.today

      # TODO: given that the instance controller is the event, the transition
      # that will be logged is the one used of the event, not for the audit.
      # Technically, that is wrong, the TimelineAudit should be logging the
      # audit transition.
      # TODO: the log_workflow method needs an extra param, defaulting to
      # @transition.
      log_workflow(audit, "autoclose")
      notify_by_role(audit, :audit_auto_close,
                     "organizer", "owner", "contributor",
                     "auditee", "auditor", "domain_owner")
    end
  end

  def email_and_notif_for(recipients, entity, category)
    recipients.each do |recipient|
      create_notification(
        category: category,
        to: recipient,
        entity: entity,
        notification_roles: entity.notification_roles_for(recipient)
      )
    end
  end

  # Actual notifications and logs
  def create_notification(options = {})
    notif = { customer: @user.customer, from: @user }.merge(options)
    NewNotification.create_and_deliver(notif)
  end

  def log_validator_operation(entity, comment = "")
    # Save the previous and the current value of what chagned.
    attrs_changed = entity.saved_changes
    attrs_changed["state"] = entity.state
    attrs_changed["role"] = "validator"
    # rubocop:disable Style/IfUnlessModifier
    if entity.respond_to?(:managed_by?) && entity.managed_by?(@user)
      attrs_changed["role"] = "cim"
    end
    # rubocop:enable Style/IfUnlessModifier

    @entity.timeline_items.create(
      author: @user,
      action: "validation response",
      comment: comment,
      object: attrs_changed.to_json
    )
  end
end
