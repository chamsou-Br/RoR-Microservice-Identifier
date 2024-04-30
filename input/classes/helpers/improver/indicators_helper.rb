# frozen_string_literal: true

module Improver::IndicatorsHelper
  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
  def indicators_filter_sentence(entity, filter, params_q_global_date_active_mode)
    if entity == Event
      scope = "improver.indicators.events"
    elsif entity == Act
      scope = "improver.indicators.acts"
    end
    # available_states = entity.states_without_creation
    available_states = entity.try(:states_without_creation) ? entity.states_without_creation : entity.states
    if filter.wf_status_ids.nil? || available_states.count == filter.wf_status_ids.count
      states = I18n.t(".filter_sentence_all_status", scope: scope)
    else
      states_array = []
      filter.wf_status_ids.each do |wf_status_id|
        states_array << entity.human_state(entity.states.key(wf_status_id.to_i))
      end
      states = states_array.join(", ")
    end
    states = "<span class='filter-sentence-highlight'>#{states}</span>"

    # Dates
    if params_q_global_date_active_mode.nil?
      dates_range = I18n.t(".last_6_months", scope: "improver.indicators.filters.dates")
    else
      case params_q_global_date_active_mode.to_i
      when 1
        dates_range = I18n.t(".last_30_days", scope: "improver.indicators.filters.dates")
      when 2
        dates_range = I18n.t(".last_3_months", scope: "improver.indicators.filters.dates")
      when 5
        dates_range = I18n.t(".last_6_months", scope: "improver.indicators.filters.dates")
      when 3
        dates_range = I18n.t(".last_12_months", scope: "improver.indicators.filters.dates")
      when 4
        if !filter.date_created_start.nil? && !filter.date_created_end.nil?
          dates_range = "#{I18n.t('.personalised_between', scope: 'improver.indicators.filters.dates')} "\
                        "#{filter.date_created_start.to_date} "\
                        "#{I18n.t('.personalised_and', scope: 'improver.indicators.filters.dates')} "\
                        "#{filter.date_created_end.to_date}"
        end
      end
    end
    dates_range = "<span class='filter-sentence-highlight'>#{dates_range}</span>"

    I18n.t(".filter_sentence", scope: scope, states: states, dates_range: dates_range).html_safe
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
end
