# frozen_string_literal: true

# TODO: Make `ActFilter` smaller by generalizing the 2 application methods
class ActFilter
  extend ActiveModel::Naming
  include ActiveModel::Model
  include ActiveModel::Serialization
  include ImproverOrderable

  # criteria filter for Act
  attr_accessor :term, :type_ids, :domain_ids, :state, :wf_status_ids,
                :responsable, :my_responsibility, :date_created_start,
                :date_created_end, :date_closed_start, :date_closed_end, :page,
                :order_by, :indicators, :origin

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
      domain_ids: @domain_ids,
      type_ids: @type_ids,
      wf_status_ids: @wf_status_ids,
      state: @state,
      responsable: @responsable,
      my_responsibility: @my_responsibility,
      term: @term,
      order_by: @order_by,
      origin: @origin
    }
  end

  # TODO: Refactor `purge_attributes` to simply #select k-v pairs from
  # `p_attributes` whose keys are in `attributes`
  #
  # return {} if p_attributes.nil?
  # p_attributes.each_with_object({}) do |(key, value), result|
  #   result[key] = value if attributes.key?(key.to_sym)
  # end
  def purge_attributes(p_attributes)
    return {} if p_attributes.nil?

    res = {}
    p_attributes.each do |key, value|
      res[key] = value if attributes.key?(key.to_sym)
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

  # TODO: Refactor `apply_filter` into smaller/generalized private methods
  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
  def apply_filter(acts, user, paginated = true)
    unless valid?
      return paginated ? ActFilter.apply_order(acts, order_by).page(page) : ActFilter.apply_order(acts, order_by)
    end

    # rubocop:disable Lint/SelfAssignment
    # acts = acts ????
    # There are no tests.
    case origin
    when ActFilter.origins[:my_task]
      acts = acts.includes(%i[contributables_contributors acts_validators]).where(
        "(owner_id = :user_id AND state != 4) OR
        (contributables_contributors.contributor_id = :user_id AND state = 1) OR
        (acts_validators.validator_id = :user_id AND state = 2)",
        user_id: user.id
      ).references(:acts_validators, :contributables_contributors)
      acts = acts
    when ActFilter.origins[:declared_by_me]
      acts = acts.where(author_id: user.id)
    when ActFilter.origins[:all]
      acts = acts
    end
    # rubocop:enable Lint/SelfAssignment

    acts = acts.where(state: Act.states[state]) if !state.blank? && Act.state_valid?(state)
    acts = acts.where(state: wf_status_ids) unless wf_status_ids.blank?
    acts = acts.where(act_type_id: type_ids) unless type_ids.blank?
    acts = acts.where(owner_id: responsable) unless responsable.blank?

    unless my_responsibility.blank?
      acts = acts.includes(:contributables_contributors)
                 .where("author_id = :author OR owner_id = :manager OR " \
                        "contributables_contributors.contributor_id = :contributor",
                        author: my_responsibility[:author],
                        manager: my_responsibility[:manager] || my_responsibility[:contributor],
                        contributor: my_responsibility[:contributor])
                 .references(:contributables_contributors)
    end

    unless date_created_start.blank? || date_created_end.blank?
      acts = acts.where("acts.created_at BETWEEN :start_date AND :end_date",
                        start_date: date_created_start.to_date,
                        end_date: date_created_end.to_date.end_of_day)
    end
    unless date_closed_start.blank? || date_closed_end.blank?
      acts = acts.where("acts.real_closed_at BETWEEN :start_date AND :end_date",
                        start_date: date_closed_start.to_date,
                        end_date: date_closed_end.to_date.end_of_day)
    end

    acts = acts.includes(:act_domains).where(act_domains: { domain_id: domain_ids }) unless domain_ids.blank?

    if term.blank?
      acts = ActFilter.apply_order(acts, order_by)
      acts = acts.page(page) if paginated
    else
      acts = if paginated
               Act.search(term, user, { must: [{ terms: { _id: acts.pluck(:id) } }] }, es_sort_dsl).page(page).records
             else
               Act.search(term, user,
                          { must: [{ terms: { _id: acts.pluck(:id) } }] },
                          es_sort_dsl.merge!(size: 1000)).records
             end
    end

    acts
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

  #
  # @param [Customer] customer
  # @return [Hash{Symbol => Object}]
  #
  # TODO: Refactor `applied_filter` into smaller/generalized private methods
  # Consider the similarities with `applied_filter` in a few other `_filter`
  # classes.  It may be possible to extract this more generally into a module
  # and include the module in each respective _filter class.
  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
  def applied_filter(customer)
    {
      domains: lambda {
        unless domain_ids.blank?
          customer.settings.improver_act_domains.where(id: domain_ids).map do |domain|
            {
              value: domain.human_label,
              q: { domain_ids: domain.id }
            }
          end
        end
      }.call,
      types: lambda {
        unless type_ids.blank?
          customer.settings.act_types.where(id: type_ids).map do |type|
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
              value: I18n.t(Act.states.key(value.to_i), scope: "activerecord.attributes.act.states"),
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
    case ActFilter.orders.key(order_by.to_i)
    when :created_up
      { sort: [{ created_at: { order: "asc" } }] }
    when :created_down
      { sort: [{ created_at: { order: "desc" } }] }
    when :last_updated_up
      { sort: [{ updated_at: { order: "asc" } }] }
    when :last_updated_down
      { sort: [{ updated_at: { order: "desc" } }] }
    when :late_act
      { sort: [{ real_closed_at: { order: "asc", missing: "_first" } },
               { estimated_closed_at: { order: "asc", missing: "_last" } }] }
    else
      { sort: [{ created_at: { order: "desc" } }] }
    end
  end
end
