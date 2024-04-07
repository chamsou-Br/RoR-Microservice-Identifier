# frozen_string_literal: true

require "active_support/concern"

# TODO: Refactor `EventFilter` into generalized filter usign modules
class EventFilter
  extend ActiveModel::Naming
  include ActiveModel::Model
  include ActiveModel::Validations
  include ActiveModel::Serialization

  include ImproverOrderable

  # criteria for search an filter
  attr_accessor :date_created_start, :date_created_end, :date_closed_start,
                :date_closed_end, :type_ids, :domain_ids, :cause_ids,
                :wf_status_ids, :state, :responsable, :my_responsibility, :term,
                :order_by, :page, :indicators, :origin

  validates :date_created_start, presence: true, if: -> { @date_created_end.present? }
  validates :date_created_end, presence: true, if: -> { @date_created_start.present? }
  validates :date_closed_start, presence: true, if: -> { @date_closed_end.present? }
  validates :date_closed_end, presence: true, if: -> { @date_closed_start.present? }

  validate :date_created_range, :date_closed_range, :date_created_range_max

  # origin filter
  def self.origins
    {
      my_task: 0,
      declared_by_me: 1,
      all: 2
    }
  end

  def attributes
    {
      date_created_start: @date_created_start,
      date_created_end: @date_created_end,
      date_closed_start: @date_closed_end,
      date_closed_end: @date_closed_end,
      type_ids: @type_ids,
      domain_ids: @domain_ids,
      wf_status_ids: @wf_status_ids,
      cause_ids: @cause_ids,
      state: @state,
      responsable: @responsable,
      my_responsibility: @my_responsibility,
      term: @term,
      order_by: @order_by,
      origin: @origin
    }
  end

  # TODO: Refactor `purge_attributes`
  # Note that this identical method also exists in `act_filter` and `audit_filter`
  def purge_attributes(p_attributes)
    res = {}

    unless p_attributes.nil?
      known_attributes = attributes.keys
      p_attributes.each do |key, value|
        res[key] = value if known_attributes.include?(key.to_sym)
      end
    end

    res
  end

  def initialize(attributes = {}, current_page = 1, indicators = false)
    attributes = purge_attributes(attributes)
    super attributes
    @page = current_page
    @order_by ||= 1
    @indicators = indicators
  end

  # TODO: Refactor `apply_filter` into smalled private methods
  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
  def apply_filter(events, user, paginated = true)
    unless valid?
      return paginated ? self.class.apply_order(events, order_by).page(page) : self.class.apply_order(events, order_by)
    end

    # rubocop:disable Lint/SelfAssignment
    # events = events ????
    # The tests are missing.
    case origin
    when EventFilter.origins[:my_task]
      events = events.includes(%i[events_continuous_improvement_managers event_validators contributables_contributors])
                     .where("( " \
                            "events_continuous_improvement_managers.continuous_improvement_manager_id = :user_id AND " \
                            "state != 3 " \
                            ") OR " \
                            "(event_validators.validator_id = :user_id AND state = 1) OR " \
                            "((contributables_contributors.contributor_id = :user_id OR " \
                            "owner_id = :user_id) AND state = 0)",
                            user_id: user.id)
                     .references(:events_continuous_improvement_managers,
                                 :event_validators,
                                 :contributables_contributors)
    when EventFilter.origins[:declared_by_me]
      events = events.where(author_id: user.id)
    when EventFilter.origins[:all]
      events = events
    end
    # rubocop:enable Lint/SelfAssignment

    unless state.blank?
      events = events.where(
        state: if Event.states[state] == Event.states[:pending_approval]
                 [Event.states[state], Event.states[:pending_closure]]
               else
                 Event.states[state]
               end
      )
    end
    unless wf_status_ids.blank?
      events = events.where(
        state: wf_status_ids.map do |state|
          state == Event.states[:pending_approval].to_s ? [state, Event.states[:pending_closure]] : state
        end.flatten
      )
    end
    events = events.where(event_type_id: type_ids) unless type_ids.blank?
    events = events.where(owner_id: responsable) unless responsable.blank?
    unless date_created_start.blank? || date_created_end.blank?
      events = events.where("events.created_at BETWEEN :start_date AND :end_date",
                            start_date: date_created_start.to_date,
                            end_date: date_created_end.to_date.end_of_day)
    end
    unless date_closed_start.blank? || date_closed_end.blank?
      events = events.where("events.closed_at BETWEEN :start_date AND :end_date",
                            start_date: date_closed_start.to_date,
                            end_date: date_closed_end.to_date.end_of_day)
    end

    unless my_responsibility.blank?
      events = events.includes(:contributables_contributors)
                     .where("author_id = :author OR owner_id = :manager OR " \
                            "contributables_contributors.contributor_id = :contributor",
                            author: my_responsibility[:author],
                            manager: my_responsibility[:manager] || my_responsibility[:contributor],
                            contributor: my_responsibility[:contributor])
                     .references(:contributables_contributors)
    end

    events = events.includes(:event_domains).where(event_domains: { domain_id: domain_ids }) unless domain_ids.blank?
    events = events.includes(:event_causes).where(event_causes: { cause_id: cause_ids }) unless cause_ids.blank?

    if term.present?
      events = if paginated
                 Event.search(term, user,
                              { must: [{ terms: { _id: events.pluck(:id) } }] },
                              es_sort_dsl.merge!(
                                size: Event.per_page,
                                from: page.to_i == 1 ? 0 : (page.to_i * Event.per_page) - Event.per_page
                              )).records
               else
                 Event.search(term, user,
                              { must: [{ terms: { _id: events.pluck(:id) } }] },
                              es_sort_dsl.merge!(size: 10_000)).records
               end
    else
      events = EventFilter.apply_order(events, order_by)
      events = events.page(page) if paginated
    end

    events
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

  #
  # @param [Customer] customer
  # @return [Hash{Symbol => Object}]
  #
  # TODO: Refactor `applied_filter` into smalled private methods
  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
  def applied_filter(customer)
    {
      domains: lambda {
        unless domain_ids.blank?
          customer.settings.improver_event_domains.where(id: domain_ids).map do |domain|
            {
              value: domain.human_label,
              q: { domain_ids: domain.id }
            }
          end
        end
      }.call,
      types: lambda {
        unless type_ids.blank?
          customer.settings.improver_types.where(id: type_ids).map do |type|
            {
              value: type.human_label,
              q: { type_ids: type.id }
            }
          end
        end
      }.call,
      status: lambda {
        unless wf_status_ids.blank?
          wf_status_ids.map do |value|
            {
              value: I18n.t(Event.states.key(value.to_i), scope: "activerecord.attributes.event.states"),
              q: { wf_status_ids: value.to_i }
            }
          end
        end
      }.call,
      responsable: lambda {
        unless responsable.blank?
          [
            {
              value: customer.users.find(responsable).name.full,
              q: { responsable: responsable }
            }
          ]
        end
      }.call,
      my_responsibility: lambda {
        unless my_responsibility.blank?
          my_responsibility.keys.map do |key|
            {
              value: I18n.t(key, scope: "improver.common.filter_label.responsibilities"),
              q: { my_responsibility: key }
            }
          end
        end
      }.call,
      created: lambda {
        [date_created_start, date_created_end] unless date_created_start.blank? || date_created_end.blank?
      }.call,
      closed: lambda {
        [date_closed_start, date_closed_end] unless date_closed_start.blank? || date_closed_end.blank?
      }.call
    }
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

  def self.responsibilities
    { author: 0, manager: 1, contributor: 2 }
  end

  def date_created_range
    return true if date_created_start.blank? || date_created_end.blank?

    flag = date_created_end.to_date.end_of_day > date_created_start.to_date
    errors.add(:date_created_end, I18n.t("improver.common.form_filter.errors.date_end")) unless flag

    flag
  end

  def date_closed_range
    return true if date_closed_start.blank? || date_closed_end.blank?

    flag = date_closed_end.to_date.end_of_day > date_closed_start.to_date
    errors.add(:date_closed_end, I18n.t("improver.common.form_filter.errors.date_end")) unless flag

    flag
  end

  def date_created_range_max
    return true unless @indicators

    flag = true
    if date_created_start.blank? ||
       date_created_end.blank? ||
       date_created_start.to_date.end_of_day + 12.months < date_created_end.to_date.end_of_day

      errors.add(:date_range_max, I18n.t("improver.common.form_filter.errors.date_range_max"))
      flag = false
    end

    flag
  end

  private

  def es_sort_dsl
    case EventFilter.orders.key(order_by.to_i)
    when :created_up
      { sort: [{ created_at: { order: "asc" } }] }
    when :created_down
      { sort: [{ created_at: { order: "desc" } }] }
    when :last_updated_up
      { sort: [{ updated_at: { order: "asc" } }] }
    when :last_updated_down
      { sort: [{ updated_at: { order: "desc" } }] }
    else
      { sort: [{ created_at: { order: "desc" } }] }
    end
  end
end
