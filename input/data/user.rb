# frozen_string_literal: true

# == Schema Information
#
# Table name: users
#
#  id                             :integer          not null, primary key
#  email                          :string(255)
#  lastname                       :string(255)
#  firstname                      :string(255)
#  created_at                     :datetime         not null
#  updated_at                     :datetime         not null
#  encrypted_password             :string(128)
#  confirmation_token             :string(128)
#  remember_token                 :string(128)
#  reset_password_token           :string(255)
#  reset_password_sent_at         :datetime
#  remember_created_at            :datetime
#  sign_in_count                  :integer          default(0)
#  current_sign_in_at             :datetime
#  last_sign_in_at                :datetime
#  current_sign_in_ip             :string(255)
#  last_sign_in_ip                :string(255)
#  customer_id                    :integer
#  function                       :string(255)
#  phone                          :string(255)
#  service                        :string(255)
#  skip_homepage                  :boolean          default(FALSE)
#  invitation_token               :string(255)
#  invitation_created_at          :datetime
#  invitation_sent_at             :datetime
#  invitation_accepted_at         :datetime
#  invitation_limit               :integer
#  invited_by_id                  :integer
#  invited_by_type                :string(255)
#  gender                         :string(255)      default("man")
#  working_date                   :datetime
#  mobile_phone                   :string(255)
#  supervisor_id                  :integer
#  deactivated                    :boolean          default(FALSE)
#  profile_type                   :string(255)      default("user")
#  language                       :string(255)      default("fr")
#  avatar                         :string(255)
#  improver_profile_type          :string(255)      default("user")
#  time_zone                      :string(255)
#  failed_attempts                :integer          default(0)
#  unlock_token                   :string(255)
#  locked_at                      :datetime
#  mail_frequency                 :string(255)      default("real_time")
#  mail_weekly_day                :integer          default(0)
#  mail_locale_hour               :integer          default(0)
#  owner                          :boolean          default(FALSE)
#  emergency_token                :string(255)
#  emergency_sent_at              :datetime
#  skip_store_video               :boolean          default(FALSE)
#  last_access_to_store           :datetime         default(Thu, 01 Jan 1970 01:00:00 CET +01:00)
#  current_access_to_store        :datetime         default(Thu, 01 Jan 1970 01:00:00 CET +01:00)
#  events_manager                 :boolean          default(TRUE)
#  actions_manager                :boolean          default(TRUE)
#  continuous_improvement_manager :boolean          default(FALSE)
#  audits_organizer               :boolean          default(TRUE)
#
# Indexes
#
#  index_users_on_current_sign_in_at                 (current_sign_in_at)
#  index_users_on_customer_id                        (customer_id)
#  index_users_on_firstname                          (firstname)
#  index_users_on_improver_profile_type              (improver_profile_type)
#  index_users_on_invitation_token                   (invitation_token) UNIQUE
#  index_users_on_invited_by_id_and_invited_by_type  (invited_by_id,invited_by_type)
#  index_users_on_lastname                           (lastname)
#  index_users_on_profile_type                       (profile_type)
#  index_users_on_remember_token                     (remember_token)
#  index_users_on_reset_password_token               (reset_password_token) UNIQUE
#  index_users_on_supervisor_id                      (supervisor_id)
#

# TODO: this requires redesigning the classes and delegation to helper.
class User < ApplicationRecord
  # FIXME: the ProcessRoles and the ImproverRoles are referring to two
  # different concepts. The former refers partially to the `role` that a user
  # has in a graph (in the association `has_many :roles, through: :roles_user`)
  # and partially to `responsibilities`. The second always refers to
  # `responsibilities`.
  #
  # All these modules should be renamed to ProcessResponsibilities, etc
  #
  include ProcessRoles
  include ImproverRoles
  include RiskModuleRoles
  include EntityExporter

  # For elasticsearch integration
  include SearchableUser
  # User import from CSV
  include UserImport
  include Sanitizable

  include TimeZoneAttribute
  include HumanNameable
  include FieldableEntity

  # notification-handler of notifications-rails
  #
  # The documentation from the gem states that the risk model does not
  # require this `include`. However there is a weird load order which
  # forces the include here.
  #
  include NotificationHandler::Target
  notification_target

  include Rails.application.routes.url_helpers

  # TODO: why is there an attachments limit?
  ATTACHMENTS_LIMIT = 10

  GENDER = %w[man woman].freeze
  MAIL_FREQUENCY = %w[none real_time daily weekly].freeze

  KEYS = %w[email lastname firstname improver_profile_type gender
            language phone mobile_phone function service mail_frequency
            working_date state invitation_created_at invitation_accepted_at
            last_sign_in_at sign_in_count roles url].freeze

  SPECIAL_KEYS = {
    profile_type: lambda { |e|
      I18n.t(e.profile_type, scope: "helpers.users.profile_type")
    },
    improver_profile_type: lambda { |e|
      I18n.t(
        e.improver_profile_type,
        scope: "helpers.users.improver_profile_type"
      )
    },
    gender: ->(e) { I18n.t(e.gender, scope: "helpers.users.gender") },
    language: ->(e) { I18n.t(e.language, scope: "helpers.users.language") },
    mail_frequency: lambda { |e|
      I18n.t(e.mail_frequency, scope: "helpers.users.mail_frequency")
    },
    state: lambda { |e|
      I18n.t(
        e.deactivated ? "deactivated" : "activated",
        scope: "helpers.users.state"
      )
    },
    roles: ->(e) { e.roles.active.pluck(:title).join(",") }
  }.freeze



  devise :invitable, :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable,
         :lockable, :saml_authenticatable, :omniauthable,
         omniauth_providers: [:ldap]

  mount_uploader :avatar, AvatarUploader

  sanitize_fields :firstname, :lastname, :function, :service

  # TODO: avatar related functions should go in its own concern
  attr_accessor :crop_x, :crop_y, :crop_w, :crop_h, :original_avatar_filename

  belongs_to :customer
  has_many :store_subscriptions

  validates :customer, presence: true

  # TODO: devise
  # Comment by: 578d975d6a fx poignart 2014-03-20 16:03:12
  # HACK: to prevent double email validations by devise validatable
  validate :remove_old_email_validation_error
  validates :email, length: { maximum: 255 },
                    presence: true,
                    uniqueness: { scope: :customer_id },
                    format: { allow_blank: true,
                              # Changed needed for Rails 5.2 upgrade. Untested.
                              # However, next two options look unnecessary.
                              # if: :email_changed?,
                              if: :will_save_change_to_email?,
                              is: true,
                              with: email_regexp }

  validates :language,
            inclusion: { in: Qualipso::Application::AVAILABLE_LOCALES.map(&:to_s) }

  validates :gender, inclusion: { in: GENDER }
  validates :mail_frequency, inclusion: { in: MAIL_FREQUENCY }

  validates :function, :service, length: { maximum: 255 }

  validates :phone, :mobile_phone, allow_blank: true,
                                   length: { maximum: 255 },
                                   format: { with: /\A[+]?[#0-9\s()-]+\z/ }

  # TODO: validations on responsibility/iam belong elsewhere
  validate :check_if_last_admin, on: :update
  validate :check_if_owner_is_active
  validate :check_if_owner_is_admin
  validate :check_supervisor_affiliation

  validates :password,
            confirmation: true,
            password_policy: true,
            if: :validate_password?

  # TODO: I wonder if this can be done more elegantly.
  # Also, what is the point of this favoring, where is it used and will it
  # change in the new UI?
  has_many :favorites
  has_many :graphs_favored, -> { where.not(state: %i[archived deactivated]) },
           through: :favorites, source: :favorisable, source_type: "Graph"
  has_many :documents_favored, lambda {
                                 where.not(state: %i[archived deactivated])
                               },
           through: :favorites, source: :favorisable, source_type: "Document"
  has_many :resources_favored,
           through: :favorites, source: :favorisable, source_type: "Resource"
  has_many :roles_favored,
           through: :favorites, source: :favorisable, source_type: "Role"
  #
  # TODO: for the moment not changing the name of the association.
  has_many :notifications_favored,
           through: :favorites, source: :favorisable,
           source_type: "ProcessNotification"
  has_many :new_notifications_favored,
           through: :favorites, source: :favorisable,
           source_type: "NewNotification"
  has_many :directories_favored,
           through: :favorites, source: :favorisable, source_type: "Directory"

  has_many :invitations, class_name: "User", as: :invited_by

  # TODO: looks like IAM, but is this role/association used?
  belongs_to :supervisor, foreign_key: "supervisor_id", class_name: "User",
                          required: false
  accepts_nested_attributes_for :supervisor

  # TODO: notifications
  has_many :process_notifications, foreign_key: "receiver_id"
  has_many :new_notifications, foreign_key: :to_id, dependent: :destroy

  # TODO: IAM
  has_many :actors, as: :responsible, dependent: :destroy

  # TODO: this is probably re: discussion
  has_many :contributions
  has_many :graphs_contribution,
           through: :contributions, source: :contributable, source_type: "Graph"

  # TODO: ?
  has_many :task_flags
  has_many :image_categories, as: :owner, dependent: :destroy
  has_many :graph_images, as: :owner, dependent: :destroy
  has_many :user_attachments, dependent: :destroy
  has_many :attachments, foreign_key: "user_id", class_name: "UserAttachment"

  # TODO: this join table should be part of the workflow
  has_many :read_confirmations

  has_many :responses

  # TODO: workflow
  # This `has_many` should eventually make the following block of `has_many`s
  # deprecated, when implementation from the risk module catches on to improver.
  has_many :entity_reviews,
           foreign_key: :reviewer_id,
           inverse_of: "reviewer",
           dependent: :destroy

  # TODO: IAM
  has_many :events_continuous_improvement_managers,
           foreign_key: "continuous_improvement_manager_id",
           class_name: "EventsContinuousImprovementManager"
  has_many :cim_events, through: :events_continuous_improvement_managers,
                        source: "event"
  has_many :event_validators, foreign_key: "validator_id",
                              class_name: "EventValidator"
  has_many :validator_events, through: :event_validators, source: "event"

  # TODO: what is this?
  has_many :accessible_resources,
           lambda { |user|
             where(deactivated: [false, user.process_power_user?].uniq)
           },
           class_name: "Resource",
           foreign_key: "customer_id",
           primary_key: "customer_id"

  # TODO: IAM
  # TODO: Deprecate these `active_`-prefixed scopes in favor of those listed
  #   below when fully moved to GraphQL for all reads/writes
  # These scopes are used in the improver_two helpers to find possible
  # responsibilities.
  #
  scope :active_improver_power_users,
        lambda {
          where(improver_profile_type: %w[admin manager],
                deactivated: false).order(%i[lastname firstname])
        }
  scope :active_improver_users,
        lambda {
          where(deactivated: false).order(%i[lastname firstname])
        }

  # Checking if it is events_, actions_manager or auditor_organizer is not
  # enough.  The DB contains records where the manager flag is true but the
  # improver profile is "user".

  scope :active_improver_events_managers,
        lambda {
          User.active_improver_power_users.where(events_manager: true)
        }
  scope :active_improver_actions_managers,
        lambda {
          User.active_improver_power_users.where(actions_manager: true)
        }
  scope :active_improver_audits_organizer,
        lambda {
          User.active_improver_power_users.where(audits_organizer: true)
        }
  scope :active_improver_continuous_improvement_managers,
        lambda {
          User.active_improver_power_users.where(
            continuous_improvement_manager: true
          )
        }
  scope :active_improver_continuous_improvement_manager_default,
        lambda {
          User.active_improver_continuous_improvement_managers.where(
            default_continuous_improvement_manager: true
          )
        }

  # Role-related composable scopes, used by GraphQL
  #
  # These are similar to the `active_`-prefixed scopes defined above with but
  # are instead composable and can therefore be used as GraphQL projection
  # scopes.
  #
  # Defining scopes as a class-constant Hash allows the scope names to be known
  # outside the `User` class and therefore, reused in GraphQL types.
  #
  # @see Enums::Scopes::UserScope
  SCOPES = {
    actions_managers: -> { improver_power_users.where(actions_manager: true) },
    active: -> { where(deactivated: false, invitation_token: nil) },
    audits_organizers: lambda {
                         improver_power_users.where(audits_organizer: true)
                       },
    candidate_instance_owners: lambda do
      where(deactivated: false,
            # User must have accepted the invitation and therefore cannot have a
            # pending invitation token
            invitation_token: nil,
            # Only Process administrators can be instance owners
            process_profile_type: [:admin])
    end,
    continuous_improvement_managers: lambda do
      improver_power_users.where(continuous_improvement_manager: true)
    end,
    continuous_improvement_manager_default: lambda do
      continuous_improvement_managers.where(
        default_continuous_improvement_manager: true
      )
    end,
    events_managers: -> { improver_power_users.where(events_manager: true) },
    improver_power_users: lambda do
      active.where(improver_profile_type: %w[admin manager])
    end
  }.merge(
    # Generate scope key-value pairs for each type of Improver profile
    IMPROVER_PROFILE_TYPES.each_with_object({}) do |type, scope_collection|
      scope_collection["improver_#{type}s"] = lambda do
        active.where(improver_profile_type: type)
      end
    end
  ).freeze

  SCOPES.each { |name, scope_proc| scope name, scope_proc }

  # TODO: is there a more elegant way of doing this?
  #
  before_destroy do
    logger.debug "On ne supprime pas un utilisateur!!!"
    raise ActiveRecord::Rollback
  end

  # TODO: IAM
  # TODO: this significantly bothers me. This should not be the entire
  # responsibilty of the User. The obligation to have it here comes from the
  # fact the other modules' responsibilities are attributes in this model.
  # TODO: In addition, the `flag&` is needed for the tests. This should change.
  #
  after_create do
    assign_pyx4_module_responsibility(:risk_module, :user) if customer.flag&.risk_module?
  end

  #
  # @return The public URL of this user.
  #
  # @note There is no `:show` action in the registrations controller, it uses
  #   `:edit` for that view for some reason.
  #
  def url
    Rails.application.routes.url_helpers.url_for(
      controller: :registrations,
      action: :edit,
      id: id,
      only_path: false,
      protocol: "https",
      host: customer.url
    )
  end

  ##
  # TODO: IAM
  # TODO: this should not be this model's responsibility. But until the IAM
  # service is implemented on other modules, it is better to leave it here.
  #
  # Assigns or re-assigns the user to a module_level responsibility.
  #
  # Roles for each module_level are mutually exclusive, eg. a user cannot be
  # both an `admin` and a `manager` in the `risk_module`.
  #
  # @example
  #   # Assign the user as a risk admin
  #   user.assign_pyx4_module_responsibility(:risk_module, :admin)
  #
  #   # Re-assign the user as a risk manager (removing the previous assignment)
  #   user.assign_pyx4_module_responsibility(:risk_module, :manager)
  #
  # @param [String] module_level - name of the pyx4 module like `risk_module`
  # @param [String] responsibility_name - of the responsibility like `admin`
  #
  # @raise [ArgumentError] if the customer has not defined the given
  # responsibility
  #
  def assign_pyx4_module_responsibility(pyx4_module, responsibility_name)
    add_responsibility_method = "add_#{pyx4_module}_#{responsibility_name}"

    unless customer.respond_to?(add_responsibility_method)
      raise ArgumentError,
            "Customer has not defined the "\
            "#{pyx4_module}_#{responsibility_name} responsibility"
    end

    actors.where(module_level: pyx4_module).destroy_all
    customer.send(add_responsibility_method, self)
  end

  #
  # Returns a reduced JSON hash of this user including only the following
  # attributes: `avatar`, `avatar_url`, `email`, `firstname`, `function`, `id`
  # and `lastname`.
  #
  # @return [Hash{String => String, Hash}]
  #
  def serialize_this
    # Use `include` to get serialized `avatar`
    as_json(include: :avatar, methods: [:avatar_url],
            only: %i[id firstname lastname email function])
  end

  # TODO: devise
  def self.send_reset_password_instructions(attributes = {})
    record = User.where(customer_id: attributes[:customer_id])
                 .where("email LIKE BINARY ?", attributes[:email])
                 .take

    recoverable = record || User.new { |u| u.errors.add(:email, :not_found) }
    recoverable.send_reset_password_instructions if recoverable.persisted?
    recoverable
  end

  # TODO: devise
  def self.find_for_authentication(conditions = {})
    logger.debug("find_for_authentication, conditions: #{conditions}")
    if conditions[:host].present?
      logger.debug("conditions[:host]=#{conditions[:host]}")
      customer = Customer.find_by_url(conditions[:host])
      conditions[:customer_id] = customer.id
      conditions.delete(:host)
      if conditions[:email].present?
        user = User.where(customer_id: customer.id).where(
          "email LIKE BINARY ?", conditions[:email]
        ).take
        unless user.nil?
          conditions[:id] = user.id
          conditions.delete(:email)
        end
      end
    end

    super
  end

  #
  # TODO: notifications
  # A list of unread notifications for the user
  #
  # @return [Array<Notification, NewNotification>]
  #
  def unread_notifications
    process_notifications.where(checked_at: nil) +
      new_notifications.where(checked_at: nil)
  end

  #
  # TODO: workflow
  # A list of graphs the user is allowed to view.  This includes graphs that are
  # not confidential and graphs where the user is either:
  #
  # - a member of a {Group} that's assigned as a viewer of the {Graph}
  # - assigned to a {Role} that's assigned as a viewer of the {Graph}
  # - assigned as a viewer of the {Graph}
  #
  # @return [ActiveRecord::Relation<Graph>]
  #
  def my_viewable_graphs
    as_viewer_of = GraphsViewer.where(viewer_id: group_ids,
                                      viewer_type: "Group")
                               .or(GraphsViewer.where(viewer: self))
                               .or(GraphsViewer.where(viewer_id: role_ids,
                                                      viewer_type: "Role"))
                               .pluck(:graph_id)

    customer.graphs.where(id: as_viewer_of)
  end

  #
  # TODO: workflow
  # A list of documents the user is allowed to view.  This includes documents
  # where the user is either:
  #
  # - a member of a {Group} that's assigned as a viewer of the {Document}
  # - assigned to a {Role} that's assigned as a viewer of the {Document}
  # - assigned as a viewer of the {Document}
  #
  # @return [ActiveRecord::Relation<Document>]
  # @note Similar to {User#all_viewable_documents} but using a unique query
  #
  def my_viewable_documents
    as_viewer_of = DocumentsViewer.where(viewer_id: group_ids,
                                         viewer_type: "Group")
                                  .or(DocumentsViewer.where(viewer: self))
                                  .or(DocumentsViewer.where(viewer_id: role_ids,
                                                            viewer_type: "Role"))
                                  .pluck(:document_id)

    customer.documents.where(id: as_viewer_of)
  end

  # TODO: workflow
  def my_reviewable_graphs
    customer
      .groupgraphs
      .includes(:graphs)
      .where(review_enable: true)
      .select do |g|
        g.last_available.in_review_period? &&
          (g.last_available.pilot == self || g.last_available.author == self)
      end
  end
  # End Notifications

  # TODO: notifications
  def add_notification(title, message)
    process_notifications.create(title: title, message: message)
  end

  #
  # Roles (not responsibilities) with which the user may be concerned
  #
  # @return [ActiveRecord::Relation<Role>]
  # @todo Remove `customer_id` filtering since that's already implied by
  #   accessing roles from the {User#customer}.
  # @todo Clarify the intentions of this method as it exists on the {User} model
  #   but only relates to a {Customer}.  Previous commits show this method did
  #   only returns roles relating to the user.
  def concerned_roles
    customer.roles.where(customer_id: customer_id, concern: true)
  end

  # This relates to roles and not responsibilities
  # Display method for best in place to handle the special case for supervisor
  #
  # @return [String]
  # @deprecated Use `user.supervisor&.name&.full_inv || ""`
  #   ({User::Name.full_inv}) instead.
  #
  def display_supervisor_name
    ActiveSupport::Deprecation.warn <<~TEXT
      `user.display_supervisor_name` is deprecated.  Use
      `user.supervisor&.name&.full_inv || ""` instead.
    TEXT

    return "" if supervisor.nil?

    "#{supervisor.lastname} #{supervisor.firstname}"
  end

  def active_for_authentication?
    super && !deactivated? && !customer.deactivated
  end

  def deactivation(bool)
    update_without_password(deactivated: bool)
  end

  #
  # TODO: IAM
  # TODO: devise
  # This really does not belong here.
  # Where and why does one need to call this method? It is being called from
  # the app/controllers/registrations_controller.rb#deactivate. Flow to study
  #
  # Deactivates all those that **can** be deactivated from the given `users`.
  #
  # @param [Array<User>] users
  #
  # @return [Array<User>]
  #
  def self.deactivate(users)
    users.reject(&:process_admin_owner?).select do |deactivatable_user|
      deactivatable_user.update_without_password(deactivated: true)
    end
  end

  # TODO: IAM
  # Candidate to move to: app/models/user/process_responsibilities.rb
  #
  # Is the user both a **Process** administrator and the customer owner?
  #
  # @return [Boolean]
  #
  def process_admin_owner?
    process_admin? && owner?
  end

  # TODO: IAM
  # Candidate to move to: app/models/user/process_responsibilities.rb
  #
  # Is the user both **activated** and a **power user**?
  #
  # @return [Boolean]
  #
  def activated_power_user?
    !deactivated? && power_user?
  end

  # TODO: IAM
  # Candidate to move to: app/models/user/process_responsibilities.rb
  #
  # Is the user a **power user**?  This information is used primarily for
  # billing purposes as such users are billed differently.
  #
  # @return [Boolean]
  #
  def power_user?
    process_power_user? || improver_power_user? || risk_module_power_user?
  end

  #
  # TODO: IAM
  # Is the user a contributor to the given `child`
  #
  # @param [Act, Audit, Document, Event, Graph] child
  #
  # @return [Boolean]
  #
  def contributor_to?(child)
    child&.contributors&.include?(self)
  end

  # Actors
  # TODO: This is probably related to notification

  def add_to_logs(child, user_id, action, comment)
    if child.instance_of?(Graph)
      GraphsLog.create(graph_id: child.id, user_id: user_id, action: action,
                       comment: comment)
    elsif child.instance_of?(Document)
      DocumentsLog.create(document_id: child.id, user_id: user_id,
                          action: action, comment: comment)
    end
  end

  def self.default_export_keys
    [KEYS, SPECIAL_KEYS]
  end

  # TODO: workflow
  # Actors.verifier
  #
  def verify(wf_entity, accept, comment, admin = nil)
    if wf_entity.instance_of?(Graph)
      row = wf_entity.graphs_verifiers.find_by_verifier_id_and_historized(id,
                                                                          false)
    elsif wf_entity.instance_of?(Document)
      row = wf_entity.documents_verifiers.find_by_verifier_id_and_historized(
        id, false
      )
    end
    row.verified = accept
    row.comment = comment
    saved = row.save
    verifier = admin.nil? ? self : admin
    if accept
      add_to_logs(wf_entity, verifier.id, "verified_by", comment)
      wf_entity.next_state(verifier)
    else
      add_to_logs(wf_entity, verifier.id, "refused_by", comment)
      wf_entity.reset_state(verifier)
    end
    saved
  end

  # /Actors.verifier
  # Actors.approver
  # TODO: workflow
  #
  def approve(wf_entity, accept, comment, admin = nil)
    if wf_entity.instance_of?(Graph)
      row = wf_entity.graphs_approvers.find_by_approver_id_and_historized(id,
                                                                          false)
    elsif wf_entity.instance_of?(Document)
      row = wf_entity.documents_approvers.find_by_approver_id_and_historized(
        id, false
      )
    end
    row.approved = accept
    row.comment = comment
    saved = row.save
    approver = admin.nil? ? self : admin

    if accept
      add_to_logs(wf_entity, approver.id, "approved_by", comment)
      wf_entity.next_state(approver)
    else
      add_to_logs(wf_entity, approver.id, "refused_by", comment)
      wf_entity.reset_state(approver)
    end
    saved
  end

  # /Actors.approver
  # TODO: workflow
  #
  # Entity deactivation
  def toggle_entity_deactivation(wf_entity, accept, comment)
    accept ? wf_entity.in_application? : wf_entity.is_deactivated?
    saved = wf_entity.save
    if accept
      deactivation = true
      add_to_logs(wf_entity, id, "deactivated_by", comment)
    else
      deactivation = false
      add_to_logs(wf_entity, id, "activated_by", comment)
    end
    wf_entity.next_state(self, deactivation)
    saved
  end
  # /Entity deactivation
  #
  # /Actors

  # Useful callback when an user has accepted an invitation
  # def invite_callback
  #  logger.debug "---->invite_callback: #{User.invitation_accepted.last.email}"
  # end

  # TODO: IAM
  def build_team_of?(wf_entity)
    designer_of?(wf_entity) ||
      verifier_of?(wf_entity) ||
      approver_of?(wf_entity) ||
      publisher_of?(wf_entity)
  end

  # TODO: IAM
  def transfer_rights_to(user)
    current_profile = profile_type
    update_column(:profile_type, user.profile_type)
    user.update_column(:profile_type, current_profile)
  end

  # TODO: notifications
  def notification_by_type_on(notifs, type)
    notifs.select do |notif|
      NotificationsController.helpers.notification_type(notif) == type
    end
  end

  # TODO: notifications
  def limite_notifications_by(number)
    notifs = []
    notifs += new_notifications.order("created_at DESC").limit(number).to_a
    if notifs.count < 20
      notifs += process_notifications.order("created_at DESC")
                                     .limit(20 - notifs.count).to_a
    end
    notifs
  end

  # TODO: avatar related functions should go in its own concern
  def crop_avatar(p_crop_x, p_crop_y, p_crop_w, p_crop_h)
    return unless crop_params? p_crop_x, p_crop_y, p_crop_w, p_crop_h

    self.crop_x = p_crop_x.to_i
    self.crop_y = p_crop_y.to_i
    self.crop_w = p_crop_w.to_i
    self.crop_h = p_crop_h.to_i
    avatar.recreate_versions!
  end

  # TODO: avatar related functions should go in its own concern
  def crop_params?(p_crop_x, p_crop_y, p_crop_w, p_crop_h)
    p_crop_x.present? || p_crop_y.present? ||
      p_crop_w.present? || p_crop_h.present?
  end

  # TODO: notifications, reminders
  # TODO: IAM
  #
  def in_reminders_build_team_of?(remindable)
    case remindable.class.name
    when "Audit"
      return true if remindable.organizer == self || remindable.owner == self

      remindable.elements.each do |element|
        return true if element.internal_auditors.include?(self)
      end
    when "Act"
      return remindable.owner == self
    end

    false
  end

  #
  # TODO: workflow
  # Has the user confirmed the reading of the given `process_entity`?
  #
  # @param [Document, Graph] process_entity
  #
  # @return [Boolean]
  #
  def confirmed_reading_of?(process_entity)
    read_confirmations.where(process: process_entity).count == 1
  end

  #
  # TODO: workflow
  def read_confirmation_for(wf_entity)
    local_confirm = read_confirmations.where(process: wf_entity)
    local_confirm.nil? ? nil : local_confirm.first
  end

  # TODO: devise
  def randomize_password
    self.password = "aA1!#{Devise.friendly_token}"
  end

  # TODO: IAM
  def manage_users
    (process_admin_owner? && customer.users_managed_by_owner?) ||
      (process_admin? && !customer.users_managed_by_owner?)
  end

  #
  # TODO: IAM
  # Can the user own the customer to which it belongs?
  #
  # A user can only own a customer if they are an active **Process**
  # administrator that is **not** already the customer owner.
  #
  # @return [Boolean]
  #
  def can_own_customer?
    process_admin? && active? && !customer_owner?
  end

  #
  # TODO: IAM
  # Is the user the current customer owner?
  #
  # @return [Boolean]
  #
  def customer_owner?
    self == customer.owner
  end

  #
  # TODO: devise
  # Is the user **active** (not deactivated, having accepted the invitation)?
  #
  # @return [Boolean]
  #
  def active?
    !deactivated? && !pending_invitation?
  end

  # TODO: devise
  def pending_invitation?
    invitation_token.present?
  end

  # This method returns the `status` of the user based on the values of the
  # attributes `deactivated` and `invitation_token`. When `invitation_token`
  # is not `nil`, the user has a pending invitation to accept and has not
  # logged in for the first time.
  # * A user is `active` if deactivated is false and has no pending invitation.
  # * A user is `deactivated` when the flag is true.
  # * A user is `pending` when the `invitation_token` is not nil.
  # * Given the conditions, there does not seem to be a way of returning
  # `unknown`. If it does, it is a sign of malfunctioning.
  #
  def status
    if active?
      "active"
    elsif deactivated?
      "deactivated"
    elsif pending_invitation?
      "pending"
    else
      "unknown"
    end
  end

  # TODO: devise
  def accept_pending_invitation
    return unless pending_invitation?

    pwd = Devise.friendly_token(128)

    self.password = self.password_confirmation = pwd
    self.invitation_accepted_at = Time.current
    self.invitation_token = nil

    save
  end

  # TODO: devise
  def sendable_invitation?
    valid_invitation? && customer.db_authen_strategy?
  end

  # TODO: notifications
  def self.with_time_zone(time_zone)
    joins(customer: :settings).where(
      "users.time_zone = ? OR (users.time_zone IS NULL AND customer_settings.time_zone = ?) ", time_zone, time_zone
    )
  end

  # TODO: notifications
  def self.with_mail_frequency_params(mail_frequency = "real_time",
                                      time_zone_hour = nil,
                                      time_zone_day = nil)
    case mail_frequency
    when "weekly"
      where(mail_frequency: mail_frequency, mail_weekly_day: time_zone_day,
            mail_locale_hour: time_zone_hour)
    when "daily"
      where(mail_frequency: mail_frequency, mail_locale_hour: time_zone_hour)
    else
      where(mail_frequency: mail_frequency)
    end
  end

  # TODO: notifications
  def self.having_mailable_new_notifications
    joins(:new_notifications).merge(NewNotification.mailable).distinct
  end

  # Relates to roles and not responsibilities
  def related_role_graphs(role_ids, with_archived = false)
    if with_archived
      graphs = customer
               .graphs.includes(:graphs_roles)
               .where(graphs_roles: { role_id: role_ids })
               .distinct.order(title: "ASC", state: "ASC", version: "ASC")
      res = []
      graphs.each do |graph|
        res << graph if GraphPolicy.viewable?(self,
                                              graph) && !res.include?(graph)
      end
      res

    else
      # using the scope from GraphPolicy to return user's related graphs
      GraphPolicy::Scope
        .new(self, nil).resolve.includes(:graphs_roles)
        .where(graphs_roles: { role_id: role_ids })
        .distinct.order(title: "ASC", state: "ASC", version: "ASC")
    end
  end

  # TODO: devise
  def set_emergency_token
    # robust token to prevent brute force attack for at least 15 mins.
    self.emergency_token = Devise.friendly_token(255)
    self.emergency_sent_at = Time.now.utc

    save(validate: false)
  end

  # TODO: devise
  def clear_emergency_token
    self.emergency_token = nil
    self.emergency_sent_at = nil

    save(validate: false)
  end

  # TODO: devise
  def valid_emergency_token?
    emergency_sent_at
      .utc
      .advance(seconds: Settings.emergency_token_timeout_in) > Time.now.utc
  end

  # TODO: IAM, the store module also needs responsibilities
  def update_accesses_to_store
    date_time_now = Time.now
    parameters = { last_access_to_store: current_access_to_store,
                   current_access_to_store: date_time_now }
    return unless date_time_now > current_access_to_store + 24.hours

    update_without_password(parameters)
  end

  # TODO: IAM
  def update_improver_profile(params)
    parameters = if params[:improver_profile_type] == "admin" ||
                    params[:improver_profile_type] == "manager"
                   {
                     improver_profile_type: params[:improver_profile_type],
                     events_manager: true,
                     actions_manager: true,
                     audits_organizer: true
                   }
                 else
                   params
                 end
    update_without_password(parameters)
  end

  #
  # TODO: IAM
  # Is the user a CIM of the given `event`?
  #
  # @param [Event] event
  #
  # @return [Boolean]
  #
  # TODO: this will soon be out-of-date as one can have cims for risk.
  def cim_of?(event)
    cim_events.include?(event)
  end

  #
  # TODO: IAM
  # Is the user a validator of the given `entity`?
  #
  # @param [Act, Event] entity
  #
  # @return [Boolean]
  #
  def validator_of?(entity)
    entity.validators.include?(self)
  end

  #
  # TODO: workflow
  # Has the user responded regarding the validation of the given `action`?
  #
  # @param [Act] action
  #
  # @return [Boolean]
  #
  def responded_to_validation_of?(action)
    return false unless validator_of?(action)

    action.acts_validators.where(response: nil, validator: self).blank?
  end

  private

  # TODO: this is a validation, not clear its purpose
  def remove_old_email_validation_error
    errors.delete(:email)
  end

  # TODO: IAM
  def check_if_last_admin
    unless will_save_change_to_profile_type? &&
           customer.is_last_active_admin?(self)
      return
    end

    errors.add :base, :last_admin
  end

  # TODO: IAM
  def check_if_owner_is_active
    return unless will_save_change_to_owner? && owner? && !active?

    errors.add :owner, :inactive
  end

  # TODO: IAM
  def check_if_owner_is_admin
    # Trying to downgrade process profile type
    errors.add :profile_type, :user_is_not_admin if owner? && !process_admin?
  end

  # TODO: devise
  def validate_password?
    customer.settings&.database? && customer.settings&.password_policy_enabled
  end

  # TODO: IAM
  def check_supervisor_affiliation
    return unless supervisor_id

    return unless customer.users.where(id: supervisor_id).none?

    errors.add :supervisor_id, :not_found
  end
end
