# frozen_string_literal: true

class AuditFilter
  extend ActiveModel::Naming
  include ActiveModel::Model
  include ActiveModel::Validations
  include ActiveModel::Serialization
  include ImproverOrderable

  attr_accessor :term, :state, :type_ids, :theme_ids, :origin, :my_responsibility,
                :wf_status_ids, :responsable, :date_created_start,
                :date_created_end, :date_closed_start, :date_closed_end, :page,
                :order_by

  validates :date_created_start, presence: true, if: -> { !@date_created_end.blank? }
  validates :date_created_end, presence: true, if: -> { !@date_created_start.blank? }
  validates :date_closed_start, presence: true, if: -> { !@date_closed_end.blank? }
  validates :date_closed_end, presence: true, if: -> { !@date_closed_start.blank? }

  validate :date_created_range, :date_closed_range

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
      theme_ids: @theme_ids,
      wf_status_ids: @wf_status_ids,
      state: @state,
      responsable: @responsable,
      my_responsibility: @my_responsibility,
      term: @term,
      order_by: @order_by,
      origin: @origin
    }
  end

  # TODO: Refactor `purge_attributes` out of this filter
  # This identical method also exists in `act_filter` and `event_filter`...
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

  def initialize(attributes = {}, current_page = 1)
    attributes = purge_attributes(attributes)
    super attributes
    @page = current_page
    @order_by = 1 if attributes.nil? || attributes[:order_by].blank?
  end

  # TODO: Refactor `apply_filter` into smaller private methods
  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
  def apply_filter(audits, user, paginated = true)
    unless valid?
      return paginated ? self.class.apply_order(audits, order_by).page(page) : self.class.apply_order(audits, order_by)
    end

    case origin
    when AuditFilter.origins[:my_task]
      user_related_to_criteria = <<~SQL
        (
          state IN (3, 4)
          AND organizer_id = :user_id
        ) OR (state != 5 AND owner_id = :user_id)
        OR (
          state IN (0, 1, 2)
          AND (
            audit_participants.participant_id = :user_id
            AND audit_participants.auditor = :auditor
          )
        ) OR (
          state IN (1, 2)
          AND (
            audit_participants.participant_id = :user_id
            AND audit_participants.audited = :auditor
          )
        ) OR (
          contributables_contributors.contributor_id = :user_id
          AND state = 0
        )
      SQL
      audits = audits.includes(%i[contributables_contributors internal_auditors
                                  internal_audited])
                     .where(user_related_to_criteria, auditor: true,
                                                      user_id: user.id)
                     .references(%i[contributables_contributors
                                    internal_auditors internal_audited
                                    audit_participants])
    when AuditFilter.origins[:declared_by_me]
      audits = audits.where(organizer_id: user.id)
    when AuditFilter.origins[:all]
      # Keep `audits` as is and do nothing
    end

    audits = audits.where(state: Audit.states[state]) if !state.blank? && Audit.state_valid?(state)
    audits = audits.where(state: wf_status_ids) unless wf_status_ids.blank?
    audits = audits.where(audit_type_id: type_ids) unless type_ids.blank?
    audits = audits.where(owner_id: responsable) unless responsable.blank?
    unless date_created_start.blank? || date_created_end.blank?
      audits = audits.where("audits.created_at BETWEEN :start_date AND :end_date",
                            start_date: date_created_start.to_date,
                            end_date: date_created_end.to_date.end_of_day)
    end
    unless date_closed_start.blank? || date_closed_end.blank?
      audits = audits.where("audits.closed_at BETWEEN :start_date AND :end_date",
                            start_date: date_closed_start.to_date,
                            end_date: date_closed_end.to_date.end_of_day)
    end

    unless my_responsibility.blank?
      audits = audits.includes(:contributables_contributors)
                     .where("organizer_id = :author OR owner_id = :manager OR " \
                            "contributables_contributors.contributor_id = :contributor",
                            author: my_responsibility[:author] || my_responsibility[:contributor],
                            manager: my_responsibility[:manager] || my_responsibility[:contributor],
                            contributor: my_responsibility[:contributor])
                     .references(:contributables_contributors)
    end

    audits = audits.includes(:audit_themes).where(audit_themes: { theme_id: theme_ids }) unless theme_ids.blank?

    if term.blank?
      audits = AuditFilter.apply_order(audits, order_by)
      audits = audits.page(page) if paginated
    else
      audits = if paginated
                 Audit.search(term, user,
                              { must: [{ terms: { _id: audits.pluck(:id) } }] },
                              es_sort_dsl).page(page).records
               else
                 Audit.search(term, user,
                              { must: [{ terms: { _id: audits.pluck(:id) } }] },
                              es_sort_dsl.merge!(size: 1000)).records
               end
    end

    audits
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

  def self.responsibilities
    { author: 0, manager: 1, contributor: 2 }
  end

  #
  # @param [Customer] customer
  # @return [Hash{Symbol => Object}]
  #
  # TODO: Refactor `applied_filter` into smalled private methods
  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
  def applied_filter(customer)
    {
      themes: lambda {
        unless theme_ids.blank?
          customer.settings.audit_themes.where(id: theme_ids).map do |theme|
            {
              value: theme.human_label,
              q: { theme_ids: theme.id }
            }
          end
        end
      }.call,
      types: lambda {
        unless type_ids.blank?
          customer.settings.audit_types.where(id: type_ids).map do |type|
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
              value: I18n.t(Audit.states.key(value.to_i), scope: "activerecord.attributes.audit.states"),
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

  private

  def es_sort_dsl
    case AuditFilter.orders.key(order_by.to_i)
    when :created_up
      { sort: [{ created_at: { order: "asc" } }] }
    when :created_down
      { sort: [{ created_at: { order: "desc" } }] }
    when :last_updated_up
      { sort: [{ updated_at: { order: "asc" } }] }
    when :last_updated_down
      { sort: [{ updated_at: { order: "desc" } }] }
    when :late_audit
      { sort: [{ completed_at: { order: "asc", missing: "_first" } },
               { estimated_closed_at: { order: "asc" } }] }
    else
      { sort: [{ created_at: { order: "desc" } }] }
    end
  end
end
