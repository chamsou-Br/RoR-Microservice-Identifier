# frozen_string_literal: true

# rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity
# rubocop:disable Metrics/MethodLength, Metrics/ParameterLists
# rubocop:disable Metrics/PerceivedComplexity
module Improver::ImproverHelper
  def date_as_block(date, icon, day_class, title)
    return "" if date.nil?

    date_img = image_tag icon, size: "32x32"
    block = "<div class='ready date_elmts' title='#{h(title)}'>
        <div class='year'>#{l(date, format: :year)}</div>
        <div class='month'>#{l(date, format: :short_month)}</div>
        <div class='circle #{day_class}'>#{l(date, format: :day_date)}</div>
        <div class='week-day'>#{l(date, format: :week_day)}</div>
        <div class='occurence_tag'>#{date_img}</div>
      </div>"
    block.html_safe
  end

  def date_as_block_with_reminder(date, icon, day_class, title, remindable, reminder)
    return "" if date.nil?

    date_img = image_tag icon, size: "32x32"
    schedulable = policy(reminder).schedule?
    block = []
    block << "<div class='ready date_elmts #{'alert' if schedulable}'>"

    if schedulable
      block << if reminder.new_record?
                 content_tag(:div, class: "alert_tag tooltip-reminder",
                                   title: reminder.class.model_name.human,
                                   data: { tooltipster_class: "schedulable" }) do
                   link_to(image_tag("improver/icons/reminder-new.svg", size: "24x24"),
                           reminder_pull_link_for(remindable, reminder),
                           remote: true,
                           class: "md-trigger",
                           data: { modal: "show-md-reminders" })
                 end
               else
                 content_tag(:div, class: "alert_tag tooltip-reminder",
                                   title: "#{reminder.class.model_name.human}: #{l(reminder.reminds_at)}",
                                   data: { tooltipster_class: "scheduled" }) do
                   link_to(image_tag("improver/icons/reminder-scheduled.svg", size: "24x24"),
                           reminder_pull_link_for(remindable, reminder),
                           remote: true,
                           class: "md-trigger",
                           data: { modal: "show-md-reminders" })
                 end
               end
    end

    block << "<div title='#{h(title)}'>"
    block <<   "<div class='year'>#{l(date, format: :year)}</div>"
    block <<   "<div class='month'>#{l(date, format: :short_month)}</div>"
    block <<   "<div class='circle #{day_class}'>#{l(date, format: :day_date)}</div>"
    block <<   "<div class='week-day'>#{l(date, format: :week_day)}</div>"
    block <<   "<div class='occurence_tag'>#{date_img}</div>"
    block << "</div>"
    block << "</div>"

    block.join.html_safe
  end

  def state_for(entity)
    if entity.instance_of?(Event)
      case entity.state
      when "under_analysis"
        raw(
          render(
            partial: entity.cim_mode? ? "improver/events/states/in_analysis_cim" : "improver/events/states/in_analysis"
          )
        ).html_safe
      when "pending_approval", "pending_closure"
        raw(render(partial: "improver/events/states/#{entity.state}")).html_safe
      when "completed"
        raw(render(partial: "improver/events/states/approved")).html_safe
      end
    elsif entity.instance_of?(Act)
      case entity.state
      when "in_creation"
        raw(render(partial: "improver/acts/states/in_creation")).html_safe
      when "in_progress"
        raw(render(partial: "improver/acts/states/in_realisation")).html_safe
      when "pending_approval"
        raw(render(partial: "improver/acts/states/in_efficiency_check")).html_safe
      end
    elsif entity.instance_of?(Audit)
      case entity.state
      when "planning"
        raw(render(partial: "improver/audits/states/planning")).html_safe
      when "planned"
        raw(render(partial: "improver/audits/states/planned")).html_safe
      when "in_progress"
        raw(render(partial: "improver/audits/states/in_realisation")).html_safe
      when "pending_approval"
        raw(render(partial: "improver/audits/states/wait_for_approval")).html_safe
      when "complete"
        raw(render(partial: "improver/audits/states/complete")).html_safe
      end
    end
  end

  def child_path_for(child)
    if child.instance_of? Graph
      graph_path(child)
    elsif child.instance_of? Document
      show_properties_document_path(child)
    elsif child.instance_of? Act
      improver_action_path(child)
    elsif child.instance_of? Audit
      improver_audit_path(child)
    elsif child.instance_of? Event
      improver_event_path(child)
    else
      "#"
    end
  end

  def child_image_url_for_impact(child, size = nil)
    size = "48x48" if size.nil?

    if child.instance_of?(Document)
      if child.url.blank?
        if child.is_msword?
          image_url("referential/file-word.svg", size: size)
        elsif child.is_pdf?
          image_url("referential/file-pdf.svg", size: size)
        elsif child.is_excel?
          image_url("referential/file-excel.svg", size: size)
        elsif child.is_ppt?
          image_url("referential/file-power.svg", size: size)
        elsif child.is_image?
          image_url("referential/file-image.svg", size: size)
        elsif child.is_audio?
          image_url("referential/file-sound.svg", size: size)
        elsif child.is_video?
          image_url("referential/file-video.svg", size: size)
        else
          image_url("referential/file-other.svg", size: size)
        end
      else
        image_url("referential/file-url.svg", size: size)
      end
    elsif child.instance_of?(Graph)
      image_url("graph/d-graph-#{child.type}.svg", size: size)
    end
  end

  def child_image_url_for_linked_file(child)
    if child.is_msword?
      image_url("referential/file-word.svg")
    elsif child.is_pdf?
      image_url("referential/file-pdf.svg")
    elsif child.is_excel?
      image_url("referential/file-excel.svg")
    elsif child.is_ppt?
      image_url("referential/file-power.svg")
    elsif child.is_image?
      image_url("referential/file-image.svg")
    elsif child.is_audio?
      image_url("referential/file-sound.svg")
    elsif child.is_video?
      image_url("referential/file-video.svg")
    else
      image_url("referential/file-other.svg")
    end
  end

  def icon_image_url_for(child)
    case child
    when Event
      case child.state
      when "under_analysis"
        image_url("improver/icons/act-analyzed-incident-icon.svg")
      when "pending_approval"
        image_url("improver/icons/act-awaiting-incident-icon.svg")
      when "completed"
        image_url("improver/icons/act-process-incident-icon.svg")
      when "closed"
        image_url("improver/icons/act-closed-icon.svg")
      else
        image_url("improver/icons/act-incident-icon.svg")
      end
    when Act
      case child.state
      when "in_creation"
        image_url("improver/icons/act-created-icon.svg")
      when "in_progress"
        image_url("improver/icons/act-progress-icon.svg")
      when "pending_approval"
        image_url("improver/icons/act-mesure-icon.svg")
      when "closed"
        image_url("improver/icons/act-closed-icon.svg")
      else
        image_url("improver/icons/act-action-icon.svg")
      end
    when Audit
      case child.state
      when "planning"
        image_url("improver/icons/adt-shedule-icon.svg")
      when "planned"
        image_url("improver/icons/adt-planner-icon.svg")
      when "in_progress"
        image_url("improver/icons/adt-insession-icon.svg")
      when "pending_approval"
        image_url("improver/icons/adt-valid-icon.svg")
      when "complete"
        image_url("improver/icons/adt-terminated-icon.svg")
      when "closed"
        image_url("improver/icons/act-closed-icon.svg")
      else
        image_url("improver/icons/act-audit-icon.svg")
      end
    end
  end

  def child_lvl_for_impact(child)
    if child.instance_of?(Graph)
      child.level
    else
      ""
    end
  end

  def reminder_pull_link_for(remindable, reminder)
    case remindable.class.name
    when "Act"
      if reminder.new_record?
        new_improver_act_reminder_path(remindable, reminder_type: reminder.reminder_type)
      else
        edit_improver_act_reminder_path(remindable, reminder)
      end
    when "Audit"
      if reminder.new_record?
        new_improver_audit_reminder_path(remindable, reminder_type: reminder.reminder_type)
      else
        edit_improver_audit_reminder_path(remindable, reminder)
      end
    end
  end

  def reminder_push_link_for(remindable, reminder = nil)
    case remindable.class.name
    when "Act"
      reminder.nil? ? improver_act_reminders_path(remindable) : improver_act_reminder_path(remindable, reminder)
    when "Audit"
      reminder.nil? ? improver_audit_reminders_path(remindable) : improver_audit_reminder_path(remindable, reminder)
    end
  end

  def localisations_labels_for_js(record)
    localisations = record.localisations
    res = "["
    i = 0
    logger.debug "All #{record.class.name} localisations => #{localisations.count}"
    localisations.each do |localisation|
      logger.debug "#{i}: #{localisation.label}"
      i += 1
      res += "{id: #{localisation.id}, text: \"#{localisation.label}\"}"
      res += "," unless i >= localisations.size
    end
    res += "]"

    res.html_safe
  end

  def improver_print_title_for(audits)
    count = audits.count
    formatted_date = I18n.l(Time.current, format: :file_export)

    return I18n.t("improver.print.print.custom_title", count: count, short_date: formatted_date) if count != 1

    entity = audits.first
    I18n.t("improver.print.print.custom_title",
           count: count,
           model_name: I18n.t("activerecord.models.#{entity.class.name.downcase}.one"),
           title: truncate_print_title(entity.object),
           short_date: formatted_date)
  end
end
# rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity
# rubocop:enable Metrics/MethodLength, Metrics/ParameterLists
# rubocop:enable Metrics/PerceivedComplexity
