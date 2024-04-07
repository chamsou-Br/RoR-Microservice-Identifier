# frozen_string_literal: true

class PackageFilter
  extend ActiveModel::Naming
  include ActiveModel::Model

  # TODO: rename packageOrigin, orderBy, privatePackage, lastModified
  # to snake_case
  #
  # rubocop: disable Naming/MethodName: Use snake_case for method names
  attr_accessor :term, :packageOrigin, :author, :orderBy, :page, :status,
                :privatePackage, :lastModified, :category

  # rubocop: enable Naming/MethodName: Use snake_case for method names

  def self.last_modified_filters
    {
      before_this_year: 0,
      this_year: 1,
      this_month: 2,
      this_week: 3,
      today: 4
    }
  end

  def self.package_origin_filters
    {
      from_my_connections: 0,
      public_packages: 1,
      from_this_instance: 2
    }
  end

  def self.public_statuses_filters
    {
      not_imported: 0,
      imported: 1
    }
  end

  def self.sort_options
    {
      title_asc: "0",
      title_desc: "1",
      last_modified_asc: "2",
      last_modified_desc: "3",
      author_asc: "6",
      author_desc: "7"
    }
  end

  def initialize(attributes = {})
    super attributes
    # TODO: Rename `@privatePackage` to `@private_package`
    # rubocop:disable Naming/VariableName
    @privatePackage = attributes[:privatePackage] == "true"
    # rubocop:enable Naming/VariableName

    # TODO: Consider using `==` instead of `===` once we've written tests for this
    # rubocop:disable Style/CaseEquality
    @last_modified_field = if @packageOrigin.to_i === PackageFilter.package_origin_filters[:from_this_instance]
                             "updated_at"
                           else
                             "published_at"
                           end
    @author_field = if @packageOrigin.to_i === PackageFilter.package_origin_filters[:from_this_instance]
                      "author"
                    else
                      "customer"
                    end
    # rubocop:enable Style/CaseEquality
  end

  # TODO: Refactor `apply_filter` into smaller, composable filter appliers
  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
  def apply_filter(user)
    case @packageOrigin.to_i
    when PackageFilter.package_origin_filters[:from_my_connections]
      pkgs = user.customer.from_my_connections_packages
    when PackageFilter.package_origin_filters[:public_packages]
      pkgs = user.customer.importable_public_packages
    when PackageFilter.package_origin_filters[:from_this_instance]
      pkgs = user.customer.from_this_instance_packages
    end

    unless @author.blank?
      pkgs = if @packageOrigin.to_i == PackageFilter.package_origin_filters[:from_this_instance]
               pkgs.where(author_id: @author)
             else
               pkgs.where(customer_id: @author)
             end
    end

    unless @status.blank?
      if @packageOrigin.to_i == PackageFilter.package_origin_filters[:from_this_instance]
        pkgs = pkgs.where(state: @status.split(","))
      else
        statuses = @status.split(",")
        if statuses.count < PackageFilter.public_statuses_filters.count
          filtered_pkgs = []
          # rubocop:disable Metrics/BlockNesting
          statuses.each do |status|
            case PackageFilter.public_statuses_filters.keys[status.to_i]
            when :not_imported
              filtered_pkgs << pkgs.where.not(id: user.customer.imported_package_entities.pluck(:id).uniq).pluck(:id)
            when :imported
              filtered_pkgs << pkgs.where(id: user.customer.imported_package_entities.pluck(:id).uniq).pluck(:id)
            end
          end
          # rubocop:enable Metrics/BlockNesting
          pkgs = Package.where(id: filtered_pkgs)
        end
      end
    end

    unless @lastModified.blank?
      case PackageFilter.last_modified_filters.keys[@lastModified.to_i]
      when :before_this_year
        pkgs = pkgs.where("packages.#{@last_modified_field} < :date ", date: Date.today.beginning_of_year)
      when :this_year
        pkgs = pkgs.where("packages.#{@last_modified_field} >= :date", date: Date.today.beginning_of_year)
      when :this_month
        pkgs = pkgs.where("packages.#{@last_modified_field} >= :date", date: Date.today.beginning_of_month)
      when :this_week
        pkgs = pkgs.where("packages.#{@last_modified_field} >= :date", date: Date.today.beginning_of_week)
      when :today
        pkgs = pkgs.where(
          "packages.#{@last_modified_field} >= :date_start and packages.#{@last_modified_field} <= :date_end",
          date_start: Date.today.beginning_of_day, date_end: Date.today.end_of_day
        )
      end
    end

    pkgs = pkgs.where(private: true) if @privatePackage

    unless @category.blank?
      pkgs = pkgs.includes(:package_categories).where(package_categories: { static_package_category_id: @category })
    end

    if @orderBy.blank?
      pkgs = pkgs.order("packages.#{@last_modified_field} DESC")
    else
      case PackageFilter.sort_options.key(@orderBy)
      when :title_asc
        pkgs = pkgs.order(name: :asc)
      when :title_desc
        pkgs = pkgs.order(name: :desc)
      when :last_modified_asc
        pkgs = pkgs.order("packages.#{@last_modified_field} ASC")
      when :last_modified_desc
        pkgs = pkgs.order("packages.#{@last_modified_field} DESC")
      when :status_asc
        pkgs = pkgs.order(state: :asc)
      when :status_desc
        pkgs = pkgs.order(state: :desc)
      when :author_asc
        pkgs = if @author_field == "customer"
                 pkgs.joins(customer: [:settings]).order("customer_settings.nickname ASC")
               else
                 pkgs.joins(@author_field.to_sym).order("users.firstname ASC, users.lastname ASC")
               end
      when :author_desc
        pkgs = if @author_field == "customer"
                 pkgs.joins(customer: [:settings]).order("customer_settings.nickname DESC")
               else
                 pkgs.joins(@author_field.to_sym).order("users.firstname DESC, users.lastname DESC")
               end
      end
    end

    pkgs.page(page)
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

  # TODO: Refactor `es_filter` into smaller, composable filter aggregators
  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
  def es_filter(user)
    filter = { bool: { must: [], must_not: [], should: [] } }

    case @packageOrigin.to_i
    when PackageFilter.package_origin_filters[:from_my_connections]
      filter[:bool][:should] << [
        { terms: { customer_connections: [user.customer_id] } },
        { bool: {
          must: [
            { terms: { customer_id: user.customer.store_connections.pluck(:connection_id) } },
            { term: { private: false } }
          ]
        } }
      ]
      filter[:bool][:must] << { term: { state: Package.states.keys[Package.states[:published]] } }
    when PackageFilter.package_origin_filters[:public_packages]
      # TODO: put here the right request now, it return non private & published packages from all customers
      filter[:bool][:must] << [
        { term: { private: false } },
        { term: { state: Package.states.keys[Package.states[:published]] } }
      ]
      filter[:bool][:must_not] << [{ term: { customer_id: user.customer_id } }]
    when PackageFilter.package_origin_filters[:from_this_instance]
      filter[:bool][:must] << { ids: { values: user.customer.packages.group(:grouppackage_id).maximum(:id).values } }
    end

    unless @author.blank?
      filter[:bool][:must] << if @packageOrigin.to_i == PackageFilter.package_origin_filters[:from_this_instance]
                                { term: { author_id: @author } }
                              else
                                { term: { customer_id: @author } }
                              end
    end

    unless @status.blank?
      if @packageOrigin.to_i == PackageFilter.package_origin_filters[:from_this_instance]
        filter[:bool][:must] << { terms: { state: @status.split(",").map { |s| Package.states.keys[s.to_i] } } }
      else
        statuses = @status.split(",")
        if statuses.count < PackageFilter.public_statuses_filters.count
          # rubocop:disable Metrics/BlockNesting
          statuses.each do |status|
            case PackageFilter.public_statuses_filters.keys[status.to_i]
            when :not_imported
              filter[:bool][:must_not] << { term: { customer_imported: user.customer.id } }
            when :imported
              filter[:bool][:must] << { term: { customer_imported: user.customer.id } }
            end
          end
          # rubocop:enable Metrics/BlockNesting
        end
      end
    end

    filter[:bool][:must] << { term: { private: true } } if @privatePackage
    filter[:bool][:must] << { term: { "categories.id" => @category } } unless @category.blank?

    unless @lastModified.blank?
      case PackageFilter.last_modified_filters.keys[@lastModified.to_i]
      when :before_this_year
        filter[:bool][:must] << { range: { "#{@last_modified_field}": { lte: Date.today.beginning_of_year } } }
      when :this_year
        filter[:bool][:must] << { range: { "#{@last_modified_field}": { gte: Date.today.beginning_of_year } } }
      when :this_month
        filter[:bool][:must] << { range: { "#{@last_modified_field}": { gte: Date.today.beginning_of_month } } }
      when :this_week
        filter[:bool][:must] << { range: { "#{@last_modified_field}": { gte: Date.today.beginning_of_week } } }
      when :today
        filter[:bool][:must] << {
          range: { "#{@last_modified_field}": { gte: Date.today.beginning_of_day, lte: Date.today.end_of_day } }
        }
      end
    end

    filter
  end
  # rubocop:enable Metrics/PerceivedComplexity

  def apply_es_filter(user)
    options = { size: Package.per_page, from: page.to_i == 1 ? 0 : (page.to_i * Package.per_page) - Package.per_page }
    unless @orderBy.blank?
      case PackageFilter.sort_options.key(@orderBy)
      when :title_asc
        options[:sort] = [{ name: { order: "asc" } }]
      when :title_desc
        options[:sort] = [{ name: { order: "desc" } }]
      when :last_modified_asc
        options[:sort] = [{ "#{@last_modified_field}": { order: "asc" } }]
      when :last_modifed_desc
        options[:sort] = [{ "#{@last_modified_field}": { order: "desc" } }]
      when :status_asc
        options[:sort] = [{ state: { order: "asc" } }]
      when :status_desc
        options[:sort] = [{ state: { order: "desc" } }]
      when :author_asc
        options[:sort] = [{
          "#{@author_field == "customer" ? "customer_nickname" : "author_full_name"}": { order: "asc" }
        }]
      when :author_desc
        options[:sort] = [{
          "#{@author_field == "customer" ? "customer_nickname" : "author_full_name"}": { order: "desc" }
        }]
      end
    end
    Package.search(term, user, es_filter(user), options).records
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength
end
