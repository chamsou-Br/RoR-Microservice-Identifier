# frozen_string_literal: true

# == Schema Information
#
# Table name: customers
#
#  id                  :integer          not null, primary key
#  url                 :string(255)
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  freemium            :boolean          default(TRUE), not null
#  internal            :boolean          default(FALSE), not null
#  language            :string(255)      default("fr")
#  max_power_user      :integer
#  max_simple_user     :integer
#  reserved            :boolean          default(FALSE), not null
#  trial               :boolean          default(FALSE), not null
#  contact_email       :string(255)
#  contact_name        :string(255)
#  contact_phone       :string(255)
#  campaign            :string(255)
#  comment             :string(765)
#  max_graphs_and_docs :integer          default(-1)
#  deactivated         :boolean          default(FALSE), not null
#  deactivated_at      :datetime
#  newsletter          :boolean          default(FALSE)
#  sage_id             :string(255)
#  internal_pu_count   :integer
#
# Indexes
#
#  index_customers_on_updated_at  (updated_at)
#  index_customers_on_url         (url)
#

# A customer is the main _tenant_ in the Pyx4 multi-tenant application.  Each
# customer is isolated from other customers.  All records persisted in the
# database either links directly to a customer (with a foreign key) or links to
# another record which itself refers to a customer.
#
class Customer < ApplicationRecord
  include IamApiMethods
  include IamCustomerSetup
  include SearchableCustomer

  attr_accessor :time_zone_offset

  alias_attribute :active_pu, :count_power_user
  alias_attribute :active_u, :count_simple_user

  validates :language, presence: true, inclusion: {
    in: Qualipso::Application::AVAILABLE_LOCALES.map(&:to_s)
  }
  validates :url, presence: true, uniqueness: true
  validates :contact_phone, format: /\A\+?[0-9 ]+\s?\z/, allow_blank: true

  # TODO: Translation: Error message should be a locale-based translated message
  validates_numericality_of :max_power_user,
                            message: "Cette valeur ne doit contenir que des chiffres.",
                            only_integer: true, allow_nil: true

  # TODO: Translation: Error message should be a locale-based translated message
  validates_numericality_of :max_simple_user,
                            message: "Cette valeur ne doit contenir que des chiffres.",
                            only_integer: true, allow_nil: true

  validates_numericality_of :internal_pu_count, only_integer: true,
                                                allow_nil: true

  validates :comment, length: { maximum: 765 }
  validate :subdomain_is_not_empty

  # @!attribute [rw] freemium
  #   @return [Boolean]
  # @!method freemium?
  #   @return [Boolean]

  # @!attribute [rw] internal
  #   @return [Boolean]
  # @!method internal?
  #   Is the customer internal to the Pyx4 organization?
  #   @return [Boolean]

  # Is this a paying customer?
  # @return [Boolean]
  def paying?
    !freemium? && !internal? && !reserved? && !trial?
  end

  # @!attribute [rw] reserved
  #   @return [Boolean]

  # @return [Boolean]
  def reserved?
    !freemium? && !internal? && reserved
  end

  # @!attribute [rw] trial
  #   @return [Boolean]
  # @!method trial?
  #   @return [Boolean]

  before_validation { |customer| customer.url = customer.url.downcase }

  has_one :flag
  has_one :owner, -> { where owner: true }, class_name: "User",
                                            inverse_of: :customer
  has_one :settings, dependent: :destroy, class_name: "CustomerSetting"
  has_one :reference_counter, dependent: :destroy
  has_one :root_directory, -> { where(parent_id: nil) }, class_name: "Directory"

  # TODO: alphabetize these associations, clean up astray comments.
  # TODO: this model is too long.
  # @!attribute [rw] users
  #   @return [ActiveRecord::Relation<User>]
  has_many :users
  has_many :groups
  has_many :roles
  has_many :directories
  has_many :documents
  has_many :models
  has_many :graphs
  has_many :resources
  has_many :recordings
  has_many :tags
  has_many :groupgraphs
  has_many :groupdocuments
  has_many :new_notifications, dependent: :destroy
  has_many :event_settings, dependent: :destroy
  has_many :act_settings, dependent: :destroy
  has_many :audit_settings, dependent: :destroy
  has_many :events
  has_many :acts
  has_many :audits
  has_many :localisations
  has_many :packages
  has_many :event_custom_properties # Values of custom settings for an event
  has_many :package_connections, dependent: :destroy
  has_many :store_connections
  has_many :store_connected_customers,
           lambda {
             where "store_connections.enabled = ?", true
           },
           through: :store_connections, source: :connection
  has_many :grouppackages
  has_many :imported_packages, dependent: :destroy
  has_many :imported_package_entities, through: :imported_packages,
                                       source: :package
  has_many :risks, dependent: :destroy
  has_many :form_fields, dependent: :destroy
  has_many :evaluation_systems, dependent: :destroy
  has_many :opportunities, dependent: :destroy

  # @!group Scopes

  # @!method external
  #   Scope returning customers that are **not** internal to the Pyx4
  #   organization
  #   @return [ActiveRecord::Relation<Customer>]
  #   @!scope class
  scope :external, -> { where(internal: false) }

  # @!method freemium
  #   Scope returning only **freemium** customers
  #   @return [ActiveRecord::Relation<Customer>]
  #   @!scope class
  scope :freemium, -> { where(freemium: true) }

  # @!method internal
  #   Scope returning only **internal** customers, typically reserved for
  #   tenants internal to the Pyx4 organization
  #   @return [ActiveRecord::Relation<Customer>]
  #   @!scope class
  scope :internal, -> { where(internal: true) }

  # @!method not_freemium
  #   Scope returning non-**freemium** customers
  #
  #   Non-freemium customers are not necessarily paying customers.
  #   @return [ActiveRecord::Relation<Customer>]
  #   @!scope class
  scope :not_freemium, -> { where(freemium: false) }

  # @!method not_reserved
  #   Scope returning customers that are **not** reserved, which is the default
  #
  #   @return [ActiveRecord::Relation<Customer>]
  #   @!scope class
  scope :not_reserved, -> { where(reserved: false) }

  # @!method not_trial
  #   Scope returning customers that do **not** have a _trial_ subscription
  #
  #   @return [ActiveRecord::Relation<Customer>]
  #   @!scope class
  scope :not_trial, -> { where(trial: false) }

  # @!method paying
  #   Scope returning paying customers which are **not** freemium, **not**
  #   internal, **not** reserved and **not** using a trial
  #
  #   @return [ActiveRecord::Relation<Customer>]
  #   @!scope class
  scope :paying, -> { not_freemium.external.not_trial.not_reserved }

  # @!method reserved
  #   Scope returning customers that are _reserved_, typically for prospective
  #   customers that want to hold a specific subdomain
  #
  #   @return [ActiveRecord::Relation<Customer>]
  #   @!scope class
  scope :reserved, -> { where(reserved: true) }

  # @!method trial
  #   Scope returning customers with a _trial_ subscription
  #
  #   @return [ActiveRecord::Relation<Customer>]
  #   @!scope class
  scope :trial, -> { where(trial: true) }

  # @!method risk_customers
  #   Scope returning customers that have a risk
  #
  #   @return [ActiveRecord::Relation<Customer>]
  #   @!scope class
  scope :risk_customers, -> { joins(:flag).where(flags: { risk_module: true }) }

  # @!method not_risk_customers
  #   Scope returning customers that don't have a risk
  #
  #   @return [ActiveRecord::Relation<Customer>]
  #   @!scope class
  scope :not_risk_customers, -> { joins(:flag).where(flags: { risk_module: false }) }

  # @!endgroup

  # Given that the existing associations between customer, customer settings
  # and beyond, are not well designed, here are methods to directly access
  # customer-wide settingsi, which are in turn objects that events can choose
  # from.  i.e., an event can choose to linked a graph, or be of a specific
  # event_type.
  #
  # The name of the methods correspond to the field_name in FormFields.
  # 'localisations' does not need a method since it exists already.
  # class: Localisation
  # def localisations
  #   localisations
  # end
  #

  # class: Graph
  def graphs_impacts
    graphs
  end

  # class: Document
  def documents_impacts
    documents
  end

  # class: EventTypeSetting
  def event_type
    settings.improver_types
  end

  # class: EventDomainSetting
  def event_domains
    settings.improver_event_domains
  end

  # class: CriticalitySetting
  def criticality
    settings.criticality_levels
  end

  # class: EventCauseSetting
  def causes
    settings.improver_causes
  end

  # class: EventAttachment
  # Attachments seem to never belong to a customer. This might change one day...
  def event_attachments
    []
  end

  # class: ActTypeSetting
  def act_type
    settings.act_types
  end

  # class: ActDomainSetting
  def act_domains
    settings.improver_act_domains
  end

  # class: ActEvalTypeSetting
  def act_eval_type
    settings.act_eval_types
  end

  # class: ActVerifTypeSetting
  def act_verif_type
    settings.act_verif_types
  end

  # class: ActAttachment
  def act_attachments
    []
  end

  # class: AuditTypeSetting
  def audit_type
    settings.audit_types
  end

  # class: AuditThemeSetting
  # The 'themes' property is aliased to 'scopes' in various places including
  # the front-end where there is a hardcoded switch, so it seems it was renamed
  # after the models were created.
  def audit_scopes
    settings.audit_themes
  end

  # class: AuditAttachment
  def audit_attachments
    []
  end

  # End of methods used in FormFields

  def root_directory
    directories.where(parent_id: nil).first
  end

  def absolute_domain_name
    "#{Settings.server.protocol}://#{url}#{Settings.server.port.nil? ? '' : ":#{Settings.server.port}"}"
  end

  def reference_counter
    super || create_reference_counter
  end

  def subdomain
    url.nil? ? "" : url.split(Settings.server.domain)[0]
  end

  def subdomain=(val)
    self.url = "#{val}#{Settings.server.domain}"
  end

  def subdomain_is_not_empty
    errors.add(:subdomain, :blank) if subdomain.blank?
  end

  def nickname
    settings.nickname || subdomain
  end

  def convenient_name
    nickname == subdomain ? nickname : "[#{nickname}](#{subdomain})"
  end

  #
  # Returns the most recent user to have signed in, if any
  #
  # @return [User, nil]
  #
  def last_user_connected
    users.order(current_sign_in_at: :desc).first
  end

  #
  # The full name of the most recently signed-in user of this customer
  #
  # @return [String, nil]
  # @deprecated Use {#last_user_connected} directly to get the last signed-in
  #   user and get their full name from {User#name} and {User::Name#full}.
  #
  def last_user_connected_name
    return nil if last_user_connected.nil?

    last_user_connected.name.full
  end

  def account_type
    if internal?
      "internal"
    elsif freemium?
      "freemium"
    elsif paying?
      "paid"
    elsif trial?
      "trial"
    elsif reserved?
      "reserved"
    end
  end

  #
  # The most recent sign-in timestamp for the last signed-in user
  #
  # @return [String, nil] string representation of the timestamp
  # @deprecated Use {#last_user_connected} directly to get the last signed-in
  #   user and get their sign-in timestamp with {User#current_sign_in_at}.
  #
  def last_user_connected_date
    return nil if last_user_connected.nil?

    last_user_connected.current_sign_in_at.to_s
  end

  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  def update_user_limits(attributes)
    self.freemium = attributes[:freemium]
    self.internal = attributes[:internal]
    self.reserved = attributes[:reserved]
    self.trial    = attributes[:trial]
    if internal?
      self.max_power_user  = nil
      self.max_simple_user = nil
      self.deactivated_at = nil
      self.deactivated = false
    elsif freemium?
      self.max_power_user  = 1
      self.max_simple_user = 0
    elsif paying? || trial?
      self.max_simple_user = count_simple_user
      self.max_power_user  = count_power_user
      if paying?
        self.deactivated_at = nil
        self.deactivated = false
      end
    elsif reserved?
      self.max_power_user  = 1
      self.max_simple_user = 1
    end
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

  #
  # Returns true if the given user can be created or re-activated without
  # exceeding user limits of the customer.
  #
  # @param [User] user - User that will be created or re-activated.
  # @return [Boolean]
  #
  def can_add_user?(user)
    can_add_a_user_of_kind?(power_user: user.power_user?)
  end

  #
  # Returns true if the given user can be re-assigned to the given
  # responsibilitys without
  # exceeding user limits of the customer.
  #
  # @param [String, Nil] process_responsibility
  #   the future responsibility of the user in Process
  # @param [String, Nil] improver_responsibility
  #   the future responsibility of the user in Improver
  # @param [String, Nil] risk_module_responsibility
  #   the future responsibility of the user in Risk
  # @return [Boolean]
  #
  def can_assign_user?(user,
                       process_responsibility: nil,
                       improver_responsibility: nil,
                       risk_module_responsibility: nil)
    return true if user.deactivated?

    process_responsibility ||= user.process_profile_type
    improver_responsibility ||= user.improver_profile_type
    risk_module_responsibility ||= user.risk_module_responsibility

    # whether or not the user will be a power user
    power_user = ![process_responsibility, improver_responsibility,
                   risk_module_responsibility].compact
                 .all?("user")

    return true if user.power_user? == power_user

    can_add_a_user_of_kind?(power_user: power_user)
  end

  #
  # Returns true if the given kind of user (simple user or power user) can be
  # added without exceeding user limits of the customer.
  #
  # can_add_power_user = can_add_user_of_kind?(power_user: true)
  # can_add_simple_user = can_add_user_of_kind?(power_user: false)
  #
  # @param [Boolean] power_user - whether or not the user will be a power user
  # @return [Boolean]
  #
  def can_add_a_user_of_kind?(power_user:)
    return true if internal?
    return false unless paying? || trial?

    if power_user
      count_power_user < (max_power_user || 1)
    else
      count_simple_user < (max_simple_user || 0)
    end
    # ^ Default limits of 1 and 0 are only for type safety. Limits are normally
    # nil only for internal and freemium customers, which are guarded above.
  end

  #
  # Returns true if we can add more simple or power users to the customer.
  #
  # @param [Integer] pu_total - number of power users to add
  # @param [Integer] u_total - number of simple users to add
  # @param [Integer] available_pu - number of power users that can be added
  # @param [Integer] available_u - number of simple users that can be added
  #
  # @return [Boolean]
  #
  # @note This is used for validating the manual import of users
  #
  # rubocop:disable Naming/PredicateName
  def is_user_limit_reached?(pu_total, u_total,
                             available_pu = available_power_users,
                             available_u = available_simple_users)
    return false if internal?
    return true unless paying? || trial?

    available_pu < pu_total || available_u < u_total
  end
  # rubocop:enable Naming/PredicateName

  # TODO: about roles. This method is inconsistent with other ways of getting
  # roles To be revised
  def available_power_users
    if paying? || trial?
      max_power_user - count_power_user
    else
      0
    end
  end

  # TODO: about roles. This method is inconsistent with other ways of getting
  # roles To be revised
  def available_simple_users
    if paying? || trial?
      max_simple_user - count_simple_user
    else
      0
    end
  end

  #
  # Returns power users of the customer, that is:
  # - Process: admins and designers
  # - Improver: admins and managers
  # - Risk module: admins and managers
  #
  # @note Deactivated power users are also returned
  #
  # @return [ActiveRecord::Relation<User>]
  #
  def power_users
    query = users.includes(:actors).references(:actors)

    process_power_users = query.where(profile_type: %w[admin designer])
    improver_power_users = query.where(improver_profile_type: %w[admin manager])
    risk_power_users = query.where(actors: { module_level: :risk_module,
                                             responsibility: %w[admin
                                                                manager] })

    process_power_users.or(improver_power_users).or(risk_power_users)
  end

  # TODO: about roles. This method is inconsistent with other ways of getting
  # roles To be revised
  def active_power_users
    power_users.where(deactivated: false)
  end

  def count_power_user
    active_power_users.count
  end

  # TODO: about roles. This method is inconsistent with other ways of getting
  # roles To be revised
  def active_simple_users
    users.where.not(id: power_users.pluck(:id))
         .where(deactivated: false)
  end

  def count_simple_user
    active_simple_users.count
  end

  def counter
    count_power_user + count_simple_user
  end

  #
  # Returns a list of users matching the given active/pending criteria
  # optionally based on the given `list`
  #
  # @param [Boolean] with_deactivated includes or excludes deactivated users
  # @param [Boolean] with_pending includes or excludes users with pending
  #   invitations
  # @param [ActiveRecord::Relation<User>, nil] list base from which to filter
  #   users
  # @return [ActiveRecord::Relation<User>]
  # @todo Since most of this method composes user queries, this should probably
  #   be rewritten as proper scopes on the {User} model and more simply composed
  #   here.
  #
  # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  def users_list(with_deactivated, with_pending, list = nil)
    list ||= users

    # return all user of this customers
    return list if with_deactivated && with_pending

    if with_deactivated && !with_pending
      # return users that are deactivated but no pending invitation
      list.where(invitation_created_at: nil).or(
        list.where.not(invitation_accepted_at: nil)
      )
    elsif !with_deactivated && with_pending
      # return users that are deactivated but have a pending invitation
      list.where(deactivated: false)
    else
      # return users that are deactivated and have no pending invitation
      # The calling method has false, false as arguments.
      list.where(deactivated: false, invitation_created_at: nil).or(
        list.where(deactivated: false).where.not(invitation_accepted_at: nil)
      )
    end
  end
  # rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

  # TODO: about roles. This method is inconsistent with other ways of getting
  # roles To be revised
  def improver_power_users
    users_list(false, false).where(improver_profile_type: %w[admin manager])
  end

  def active_roles
    roles.where(deactivated: false)
  end

  def deactivated_roles
    roles.where(deactivated: true)
  end

  # rubocop:disable Naming/PredicateName
  # TODO: Rename `is_last_active_admin?` to `last_active_admin?`
  # TODO: rewrite.
  #
  def is_last_active_admin?(user)
    # For reference, here is the signature of the method users_list
    # def users_list(with_deactivated, with_pending, list = nil)
    #
    active_admin_list = users_list(false, false).where(profile_type: "admin")
    active_admin_list.count == 1 && user.id == active_admin_list.first.id
  end
  # rubocop:enable Naming/PredicateName

  ## Customer access to modules and special features
  # For now a customer always has access to the process module.
  def process?
    true
  end

  # Customer always has access to the user_module.
  def user_module?
    true
  end

  # These methods delegate to the flag model to know if the customer has access
  # to the modules Improver, Risk and Store.
  # * `renaissance?` should be deleted along with ALL its code.
  # * No idea AT ALL what this `graph_steps?` method is for...
  #
  %i[improver? risk_module? store? renaissance? graph_steps?].each do |method|
    delegate method, to: :flag
  end

  # TODO: These methods should simply drop the prefix and be deprecated.
  #
  def access_improver?
    improver?
  end

  def access_store?
    store?
  end

  # TODO: This method should drop the prefix, or leave `in`.
  # The method delegates to the flag model to know if the customer is in the
  # migration state.
  #
  delegate :migration?, to: :flag, prefix: :is_in

  def sso_access?
    flag.sso && !freemium
  end

  def ldap_access?
    flag.ldap && !freemium
  end
  ## END Customer access to modules and special features

  def last_twenty_applicable_graphs
    graphs.where(state: "applicable", confidential: false).limit(20)
  end

  def root_graph
    root_groupgraph = groupgraphs.where(root: true).first
    return root_groupgraph.applicable_version unless root_groupgraph.nil?
  end

  def sign_in_count
    users.pluck(:sign_in_count).sum
  end

  def created_graph_count
    graphs.count
  end

  # rubocop:disable Metrics/AbcSize
  def self.freemium_stats_by_week
    result = {}

    where(internal: false, freemium: true)
      .group_by { |item| item.created_at.strftime("%Y-%W") }
      .sort.each do |week, freemiums|
      result[week] = {
        count: freemiums.count,
        active: joins(:users).where(id: freemiums.select { |freem| freem["id"] })
                             .where("users.last_sign_in_at >= :connect_date", connect_date: 1.week.ago)
                             .references(:users).distinct.count
      }
    end

    result[:last_week] = result.delete(Date.yesterday.strftime("%Y-%W"))

    result.to_a.reverse.to_h
  end
  # rubocop:enable Metrics/AbcSize

  # TODO: Refactor `self.report_stats_to_dashboard` to external these POST
  # requests.
  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  def self.report_stats_to_dashboard
    HTTParty.post(
      "http://dashboard.qualiproto.fr/widgets/customers",
      body: {
        auth_token: "ceciestuntoken",
        current: Customer.count,
        internal: Customer.where(internal: true).count
      }.to_json
    )

    HTTParty.post(
      "http://dashboard.qualiproto.fr/widgets/users",
      body: {
        auth_token: "ceciestuntoken",
        current: User.count,
        internal: User.joins(:customer).where("customers.internal = true").count
      }.to_json
    )

    HTTParty.post(
      "http://dashboard.qualiproto.fr/widgets/users24",
      body: {
        auth_token: "ceciestuntoken",
        current: User.joins(:customer)
                     .where("current_sign_in_at > ?", Time.now - 1.day).count,
        internal: User.joins(:customer)
                      .where("customers.internal = true")
                      .where("current_sign_in_at > ?", Time.now - 1.day).count
      }.to_json
    )

    customers = Customer.joins(:users).group("users.customer_id")
                        .order("count(users.customer_id) desc").limit(10)

    HTTParty.post(
      "http://dashboard.qualiproto.fr/widgets/topcustomers",
      body: {
        auth_token: "ceciestuntoken",
        items: customers.map { |c| { label: c.url, value: c.users.count } }
      }.to_json
    )
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

  def time_zone
    settings.time_zone
  end

  #
  # Update's the customer's owner to the provided user. To update the customer's
  # owner successfully, the provided user must:
  #
  # - Not already be the customer owner
  # - Meet the user requirements for being a customer owner (has no errors)
  #
  # @param [User] owner_to_be
  #
  # @return [User] the provided user
  #
  def update_instance_ownership(owner_to_be)
    unless owner_to_be.is_a?(User)
      raise ArgumentError, "Expected provided owner candidate to be a User " \
                           "but received a #{owner_to_be.class}: #{owner_to_be}"
    end

    if owner_to_be.customer_owner?
      owner_to_be.errors.add :owner, :current_owner
      return owner_to_be
    end

    owner_to_be.update_without_password(owner: true)
    unless owner_to_be.customer.owner.nil? || owner_to_be.errors.any?
      owner_to_be.customer.owner.update_without_password owner: false
    end

    owner_to_be
  end

  def users_managed_by_owner?
    settings.owner_users_management
  end

  # TODO: Refactor into shared concern or module
  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  def self.to_csv(options = {})
    CSV.generate(options) do |csv|
      customers_data = all.map do |customer|
        [
          customer.url,
          customer.nickname,
          customer.created_at,
          customer.updated_at,
          customer.language,
          customer.max_power_user,
          customer.max_simple_user,
          customer.active_pu,
          customer.active_u,
          customer.internal_pu_count,
          customer.contact_email,
          customer.contact_name,
          customer.contact_phone,
          customer.sage_id,
          customer.comment,
          customer.campaign,
          customer.account_type,
          customer.last_user_connected_name,
          customer.last_user_connected_date,
          customer.sign_in_count,
          customer.created_graph_count,
          customer.access_improver?,
          customer.risk_module?,
          customer.deactivated,
          customer.deactivated_at,
          customer.paying?
        ]
      end

      # Columns
      header = %w[
        url name created_at updated_at language max_power_user max_simple_user
        active_pu active_u internal_pu_count contact_email contact_name
        contact_phone sage_id comment campaign account_type
        last_user_connected_name last_user_connected_date sign_in_count
        created_graph_count access_improver? access_risk? deactivated
        deactivated_at paying_instance?
      ].map do |customer_attr|
        customer_attr
      end

      # Fill CSV
      csv << header
      customers_data.each do |customer_array|
        csv << customer_array
      end
    end
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

  # TODO: Should refactor into smaller component methods.
  # This method seems to resemble `to_csv` from other classes.  There may be
  # some redundancy here that can be factored out.
  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  #
  # TODO: include "Profil PYX4 Risk"
  def self.export_pu(options = {})
    headers = [
      "Customer", "account_type", "Email", "Nom", "Prénom",
      "Profil PYX4 Process", "Profil PYX4 Improver", "Profil PYX4 Risk",
      "Genre", "Langue", "Téléphone (Bureau)", "Téléphone (Mobile)",
      "Fonction", "Service", "Date d'entrée", "Désactivé?"
    ]

    CSV.generate(options) do |csv|
      csv << headers

      all.each do |customer|
        customer.users.each do |user|
          next unless user.power_user?

          # On ne prend que les PU
          component = {
            customer: customer.url,
            account_type: customer.account_type,
            email: user.email,
            lastname: user.lastname,
            firstname: user.firstname,
            profile_type: user.profile_type,
            improver_profile_type: user.improver_profile_type,
            risk_profile_type: user.risk_module_responsibility,
            gender: user.gender,
            language: user.language,
            phone: user.phone,
            mobile_phone: user.mobile_phone,
            function: user.function,
            user_service: user.service,
            working_date: user.working_date,
            deactivated: user.deactivated
          }
          res_line = []
          component.each do |_key, value|
            res_line << value.to_s
          end
          csv << res_line
        end
      end
    end
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

  def db_authen_strategy?
    settings&.database?
  end

  def saml_auth_strategy?
    settings.saml?
  end

  def ldap_auth_strategy?
    settings.ldap?
  end

  def from_my_connections_packages
    Package
      .includes(:package_connections)
      .where(
        "packages.customer_id IN (:connection_customer) AND " \
        "(package_connections.customer_id = :customer OR packages.private = false) " \
        "AND state = :state",
        state: Package.states[:published],
        customer: id,
        connection_customer: store_connected_customers.pluck(:connection_id)
      ).references(:package_connections)
  end

  def from_this_instance_packages
    package_ids = []
    grouppackages.each do |grouppackage|
      package_ids << grouppackage.last_available.id unless grouppackage.last_available.nil?
    end

    Package.where(id: package_ids)
  end

  def store_connection_requests
    StoreConnection.where(connection_id: id, enabled: false)
  end

  def importable_public_packages
    Package.where(private: false,
                  state: Package.states[:published]).where.not(customer: self)
  end

  def graphs_applicable_versions
    graphs.where(state: "applicable").order(:level, :title)
  end

  def graphs_latest_versions
    latest_graph_ids = graphs.order("created_at DESC")
                             .to_a
                             .uniq(&:groupgraph_id)
                             .map(&:id)
    graphs.where(id: latest_graph_ids).order(:level, :title)
  end

  def graphs_and_docs_left
    if max_graphs_and_docs == -1
      -1
    elsif max_graphs_and_docs <= (groupgraphs.count + groupdocuments.count)
      0
    else
      max_graphs_and_docs - (groupgraphs.count + groupdocuments.count)
    end
  end

  def max_graphs_and_docs_reached?
    max_graphs_and_docs != -1 && graphs_and_docs_left <= 0
  end

  def current_graphs_and_docs
    groupgraphs.count + groupdocuments.count
  end

  # TODO: Rename `importedPackage?` to `imported_package?`  Occurences seem to
  # only appear in app/serializers/package_serializer.rb
  # rubocop:disable Naming/MethodName
  def importedPackage?(package, specific_version = false)
    return imported_package_entities.include?(package) if specific_version

    imported_package_entities.each do |imported_package|
      return true if imported_package.grouppackage == package.grouppackage
    end

    false
  end
  # rubocop:enable Naming/MethodName

  def event_managers
    users.active_improver_power_users.where(events_manager: true)
  end

  def self.check_scheduled_deactivation
    Customer.where(" deactivated_at < ?  and deactivated = ? ",
                   5.minutes.from_now, false).each do |customer|
      customer.update_attribute(:deactivated, true)
    end
  end

  def deactivated_at_french_format
    return if deactivated_at.nil?

    date_only = deactivated_at.to_s.split[0]
    splitted_date = date_only.to_s.split("-")

    if !splitted_date[2].nil? &&
       !splitted_date[1].nil? &&
       !splitted_date[0].nil?
      "#{splitted_date[2]}/#{splitted_date[1]}/#{splitted_date[0]}"
    else
      ""
    end
  end

  # required stuff for new customer

  def add_customer_settings
    return if CustomerSetting.find_by_customer_id(self)

    customer_time_zone = ActiveSupport::TimeZone[-time_zone_offset.to_i]
    CustomerSetting.create!(customer_id: id, time_zone: customer_time_zone.name)
  end

  # TODO: Seems redundant since ActiveRecord adds a `create_flag!` method for
  # this model which does exactly `Flag.create!(customer_id: id)`.
  # We can remove this method entirely and add create_flag! directly in the
  # `after_create` hook above.
  def add_flag
    Flag.create!(customer_id: id)
  end

  # TODO: What is `add_models` for and why is it in the Customer model?
  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  def add_models
    # Pour l'instant, on ne gère pas correctement les modèles / landscape /
    # human etc...
    #
    models.create!(type: "process", level: 1,
                   name: I18n.t("model.name.process1"), landscape: true)
    models.create!(type: "process", level: 2,
                   name: I18n.t("model.name.process2"), landscape: false)
    models.create!(type: "process", level: 3,
                   name: I18n.t("model.name.process3"), landscape: false)
    models.create!(type: "process", level: 3,
                   name: I18n.t("model.name.process3tree"), landscape:
                   false, tree: true)
    models.create!(type: "human", level: 1, name: I18n.t("model.name.human1"),
                   landscape: true)
    models.create!(type: "human", level: 2, name: I18n.t("model.name.human2"),
                   landscape: false)
    models.create!(type: "human", level: 3, name: I18n.t("model.name.human3"),
                   landscape: false)
    models.create!(type: "environment", level: 1,
                   name: I18n.t("model.name.environment1"), landscape: true)
    models.create!(type: "environment", level: 2,
                   name: I18n.t("model.name.environment2"), landscape: false)
    models.create!(type: "environment", level: 3,
                   name: I18n.t("model.name.environment3"), landscape: false)
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

  def create_root_directory
    Directory.create(name: I18n.t("directory.root.name")) do |directory|
      directory.customer = self
    end
  end

  #
  # Returns the current applicable evaluation system for this customer.
  # NOTE: this will be changed to implement different types of evaluation
  # systems, in which case the scope will be customer_id and type.
  #
  # @raise [ActiveRecord::RecordNotFound] if there is more than one evaluation
  # system in the scope.
  #
  # @return [EvaluationSystem] if found
  # @return nil when there are no applicable evaluation systems
  #
  def applicable_evaluation_system
    eval_system = evaluation_systems.select(&:applicable?).uniq

    raise ActiveRecord::RecordNotFound if eval_system.count > 1

    eval_system.first
  end

  # Returns the current applicable evaluation system for this customer, for
  # the purpose of creating a new one..
  #
  # The current evalution is the applicable one if it exists, otherwise it is
  # the last archived. It neither exist, then returns nil.
  #
  # @return [EvaluationSystem] if found
  # @return nil if not found
  #
  def current_evaluation_system
    applicable_system = applicable_evaluation_system

    # Current evaluation system is the applicable one
    return applicable_system if applicable_system

    # Current evaluation system is the last archived
    evaluation_systems.reverse.find(&:archived?)
  end
end
