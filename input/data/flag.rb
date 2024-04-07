# frozen_string_literal: true

# == Schema Information
#
# Table name: flags
#
#  id          :integer          not null, primary key
#  customer_id :integer
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  improver    :boolean          default(FALSE)
#  migration   :boolean          default(FALSE)
#  graph_steps :boolean          default(FALSE)
#  sso         :boolean          default(FALSE)
#  renaissance :boolean          default(FALSE)
#  store       :boolean          default(FALSE)
#  ldap        :boolean          default(FALSE)
#  risk_module :boolean          default(FALSE)
#
# Indexes
#
#  index_flags_on_customer_id  (customer_id)
#

class Flag < ApplicationRecord
  belongs_to :customer

  # TODO: This validation is not needed, it is covered by the `belongs_to` assoc
  validates :customer, presence: true, uniqueness: true
  validates :graph_steps, :improver, :ldap, :migration, :renaissance,
            :risk_module, :sso, :store, inclusion: { in: [true, false] }

  after_create :add_user_form_fields

  after_update :add_improver_dependencies,
               if: -> { saved_change_to_improver? && improver? }
  after_update :add_risk_form_fields, :add_risk_actors,
               if: -> { saved_change_to_risk_module? && risk_module? }

  private

  def add_user_form_fields
    UserFormFields.create_form_fields(customer)
  end

  def add_improver_dependencies
    add_default_prefixes
    add_improver_form_fields
  end

  def add_default_prefixes
    return if customer.settings.reference_setting

    customer.settings.add_improver_prefixes
  end

  def add_improver_form_fields
    return if customer.form_fields.improver_predef.exists?

    ImproverFormFields.create_form_fields(customer)
  end

  def add_risk_form_fields
    return if customer.form_fields.risk_predef.exists?

    RiskFormFields.create_form_fields(customer)
    EvaluationFormFields.create_defaults(customer)
  end

  ##
  # Assigns as normal risk users the customer users that do not have a
  # responsibility in the Risk module.
  # The customer owner will be assigned as an admin and also as a potential
  # risk owner if there is none.
  #
  def add_risk_actors
    risk_user_ids = customer.users.includes(:actors)
                            .where(actors: { module_level: "risk_module" })
                            .pluck(:id)

    users_without_responsibility = customer.users.where.not(id: risk_user_ids)

    customer.add_risk_module_users(users_without_responsibility)

    return if customer.owner.nil?

    customer.owner.assign_pyx4_module_responsibility(:risk_module, :admin)
    customer.add_risk_owner(customer.owner) if customer.risk_owners.empty?

    # TODO: some of the previous code can be simplified and the method
    # `assign_pyx4_module_responsibility` needs to be deprecated. The following
    # code is part of the replacement but needs testing.
    #
    # Adds all customer users as normal risk module users
    #   customer.add_risk_module_users(customer.users)
    #   customer.add_risk_module_admin(customer.owner)
  end
end
