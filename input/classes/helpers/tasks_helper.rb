# frozen_string_literal: true

module TasksHelper
  # Return the corresponding module {modelor|improver}
  # TODO: Use switch case when other modules are available.
  def task_module(entity)
    if [Graph, Document].include? entity.class
      "modelor"
    elsif [Act, Event, Audit].include? entity.class
      "improver"
    end
  end

  def mark_as_read_button(task)
    return if task.read?

    link_to(mark_read_task_path(task),
            title: I18n.t(".mark_as_read", scope: "tasks.tasks_list"),
            remote: true) do
      image_tag("dashboard/trash-can-icon.svg", size: "18x18")
    end
  end

  # rubocop:disable Metrics/MethodLength
  def message_for(entity, message, options)
    html_message = "<p style='task_message'>#{t(message, **options)}</p>"
    return_message_only = false

    case entity.class.name
    when "Graph"
      entity_name = "graph"
    when "Document"
      entity_name = "document"
    else
      return_message_only = true
    end

    case entity.state.to_sym
    when :verificationInProgress
      method_entity_action_path = "accept_#{entity_name}_verifier_path"
      entity_translate_action_path = "#{entity_name}s.states.verify.accept"
    when :approvalInProgress
      method_entity_action_path = "approve_#{entity_name}_approver_path"
      entity_translate_action_path = "#{entity_name}s.states.approve.accept"
    when :approved
      method_entity_action_path = "publish_#{entity_name}_publisher_path"
      entity_translate_action_path = "#{entity_name}s.states.publish.publish_now"
    else
      return_message_only = true
    end

    "#{html_message} #{unless return_message_only
                         button_to(t(entity_translate_action_path),
                                   send(method_entity_action_path, entity, current_user),
                                   data: { disable_with: I18n.t('common.loading') },
                                   class: 'button_validation')
                       end}"
  end
  # rubocop:enable Metrics/MethodLength

  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity,
  # rubocop:disable Metrics/PerceivedComplexity, Metrics/MethodLength
  def task_message(entity, category, options = {})
    url = task_url(entity)

    scope = task_i18n_scope(entity, category, options)
    locale = current_user.language
    taskable = task_i18n_taskable(entity, locale).downcase
    link = ActionController::Base.helpers.link_to(url) do
      render_for_html(entity_title(entity))
    end

    options = { scope: scope, locale: locale, taskable: taskable, link: link }

    if entity.instance_of?(Act) && entity.in_creation? && entity.estimated_start_at_date.nil?
      t(:message_without_start_at, **options)

    elsif entity.instance_of?(Act) || entity.instance_of?(Audit)
      start_date, end_date = [entity.estimated_start_at_date,
                              entity.estimated_closed_at_date].map do |date|
        task_highlight_date(date)
      end

      t(:message, **options, start_date: start_date, end_date: end_date)

    elsif entity.is_a?(Graph) && category.to_sym == :graph_review
      deadline = task_highlight_date(entity.groupgraph.review_date)

      t(:message, **options, deadline: deadline)
    else
      message_for(entity, :message, options)
    end
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity,
  # rubocop:enable Metrics/PerceivedComplexity, Metrics/MethodLength

  def task_url(entity)
    case task_module(entity)
    when "modelor"
      polymorphic_url(entity, host: entity.customer.url)
    when "improver"
      if entity.is_a?(Act)
        return improver_action_url(
          entity, host: entity.customer.url
        )
      end

      polymorphic_url([:improver, entity], host: entity.customer.url)
    end
  end

  def task_i18n_scope(entity, category, options)
    scope = [:activerecord, :attributes, :task, :action_type,
             entity.class.name.downcase]

    if entity.instance_of?(Audit) && entity.in_progress?
      audit_task_i18n_scope(entity, category, options)
    elsif category.to_sym == :graph_review
      scope.concat([category])
    elsif category == :read_confirmations
      entity_confirmation_task_i18n_scope(entity, category)
    elsif category.to_sym == :read_confirmation
      scope.concat([:read_confirmation])
    else
      scope.concat([entity.state])
    end
  end

  def task_has_time_constraint?(entity)
    (entity.is_a?(Act) && entity.in_creation?) ||
      (entity.is_a?(Audit) && (entity.planned? || entity.in_progress?))
  end

  def audit_task_i18n_scope(entity, category, _options)
    scope = [:activerecord, :attributes, :task, :action_type,
             entity.class.name.downcase, entity.state]
    case category.to_sym
    when :audits_in_progress_owner
      scope.concat([:owner])
    when :audits_in_progress_auditor
      scope.concat([:auditor])
    end
  end

  def entity_confirmation_task_i18n_scope(entity, category)
    [:activerecord, :attributes, :task, :action_type,
     entity.class.name.downcase, category]
  end

  def task_date(_entity)
    ""
  end

  def task_highlight_date(date)
    content_tag(:span, date, class: "strong-900")
  end

  def task_i18n_taskable(entity, locale = nil)
    taskable_class = entity.instance_of?(Contribution) ? entity.contributable.class : entity.class

    if locale.nil?
      t(taskable_class.name.downcase, scope: %i[activerecord models], count: 1)
    else
      t(taskable_class.name.downcase, scope: %i[activerecord models],
                                      locale: locale, count: 1)
    end
  end

  # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  def entity_title(entity)
    case entity
    when Contribution
      entity = self.entity.contributable
    when Reminder
      return (entity.remindable.nil? ? nil : entity.title_for_remindable)
    end

    if entity.respond_to?(:title)
      entity.title
    elsif entity.respond_to?(:name)
      entity.name
    elsif entity.respond_to?(:label)
      entity.label
    elsif entity.respond_to?(:description)
      entity.description.truncate 60
    elsif entity.respond_to?(:object)
      entity.object.truncate 60
    end
  end
  # rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
end
