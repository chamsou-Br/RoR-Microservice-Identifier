# frozen_string_literal: true

# == Schema Information
#
# Table name: customer_settings
#
#  id                                     :integer          not null, primary key
#  customer_id                            :integer
#  created_at                             :datetime         not null
#  updated_at                             :datetime         not null
#  logo                                   :string(255)
#  time_zone                              :string(255)
#  print_footer                           :string(100)
#  allow_iframe                           :boolean          default(FALSE)
#  approved_read                          :integer          default("approved_disabled")
#  owner_users_management                 :boolean          default(FALSE)
#  authentication_strategy                :integer          default("database")
#  referent_contact                       :string(255)
#  nickname                               :string(255)
#  continuous_improvement_active          :boolean          default(FALSE)
#  default_continuous_improvement_manager :integer
#  localisation_preference                :integer          default("freely_add"), not null
#  logo_usage                             :integer          default("application_print")
#  password_policy_enabled                :boolean          default(FALSE)
#  automatic_user_deactivation_enabled    :boolean          default(FALSE), not null
#  deactivation_wait_period_days          :integer          default(30), not null
#
# Indexes
#
#  index_customer_settings_on_customer_id  (customer_id)
#

# TODO: Refactor some record-creating methods into an external module
class CustomerSetting < ApplicationRecord
  MIN_DEACTIVATION_PERIOD = 10
  MAX_DEACTIVATION_PERIOD = 365
  include LogoFile
  include TimeZoneAttribute

  belongs_to :customer
  belongs_to :default_cim,
             foreign_key: "default_continuous_improvement_manager",
             class_name: "User",
             optional: true

  has_many :pastilles, dependent: :destroy, class_name: "PastilleSetting"

  has_many :improver_types, dependent: :destroy, class_name: "EventTypeSetting"
  has_many :improver_event_domains, dependent: :destroy, class_name: "EventDomainSetting"
  has_many :improver_act_domains, dependent: :destroy, class_name: "ActDomainSetting"
  has_many :improver_causes, dependent: :destroy, class_name: "EventCauseSetting"
  has_many :act_types, dependent: :destroy, class_name: "ActTypeSetting"
  has_many :act_verif_types, dependent: :destroy, class_name: "ActVerifTypeSetting"
  has_many :act_eval_types, dependent: :destroy, class_name: "ActEvalTypeSetting"
  has_many :audit_types, dependent: :destroy, class_name: "AuditTypeSetting"
  has_many :audit_themes, dependent: :destroy, class_name: "AuditThemeSetting"
  has_many :criticality_levels, dependent: :destroy, class_name: "CriticalitySetting"

  has_many :graph_images, -> { where(deactivated: false) }, as: :owner, dependent: :destroy
  has_many :image_categories, as: :owner, dependent: :destroy
  has_many :colors, dependent: :destroy
  has_many :ldap_settings, dependent: :destroy

  has_one :reference_setting, dependent: :destroy
  has_one :sso_settings, dependent: :destroy, class_name: "CustomerSsoSetting"

  enum approved_read: { approved_disabled: 0, approved_graph: 1,
                        approved_document: 2, approved_graph_and_document: 3 }
  enum logo_usage: { application_print: 0, application_print_mail: 1 }
  enum authentication_strategy: { database: 0, saml: 1, ldap: 2 }

  enum localisation_preference: { freely_add: 0, only_predefined: 1 }, _suffix: :locations

  validates :print_footer, length: { maximum: 100 }
  validates :authentication_strategy, inclusion: { in: authentication_strategies.keys }
  validates :referent_contact, email: true, allow_blank: true, length: { maximum: 100 }
  validates :nickname, length: { maximum: 100 }
  validates :deactivation_wait_period_days,
            presence: true,
            numericality: {
              only_integer: true,
              greater_than_or_equal_to: MIN_DEACTIVATION_PERIOD,
              less_than_or_equal_to: MAX_DEACTIVATION_PERIOD
            }

  validate :check_sso_settings, if: lambda { |cs|
    cs.will_save_change_to_authentication_strategy? && cs.saml?
  }
  validate :check_ldap_settings, if: lambda { |cs|
    cs.will_save_change_to_authentication_strategy? && cs.ldap?
  }

  accepts_nested_attributes_for :pastilles,
                                allow_destroy: true,
                                reject_if: proc { |ps|
                                  ps["label"].blank? && ps["desc_en"].blank? &&
                                    ps["desc_fr"].blank? && ps["desc_es"].blank? &&
                                    ps["desc_de"].blank?
                                }

  accepts_nested_attributes_for :graph_images, allow_destroy: true

  def nickname
    self[:nickname].blank? ? customer.subdomain : self[:nickname]
  end

  def pastilles_default
    pastilles.default
  end

  def pastilles_custom
    pastilles.custom
  end

  def count_categories
    image_categories.count + 1
  end

  def approved_read_graph?
    approved_graph? || approved_graph_and_document?
  end

  def approved_read_document?
    approved_document? || approved_graph_and_document?
  end

  def continuous_improvement_should_be_off?(user_params, improver_power_users)
    improver_power_users.where(continuous_improvement_manager: true).none? &&
      user_params.key?(:continuous_improvement_manager) &&
      user_params[:continuous_improvement_manager] == "false"
  end

  def update_default_continuous_improvement_manager
    user = customer.users.active_improver_power_users.where(continuous_improvement_manager: true).first

    if user.nil?
      user = customer.users.active_improver_power_users.first
      user.update(continuous_improvement_manager: true)
    end
    update(default_cim: user)

    user
  end

  # required for a new record

  def add_colors
    colors.create(value: "40c353", default: true, active: true, position: 1)
    colors.create(value: "e3e31f", default: true, active: true, position: 2)
    colors.create(value: "e89c30", default: true, active: true, position: 3)
    colors.create(value: "c53e3e", default: true, active: true, position: 4)
    colors.create(value: "6a3fc4", default: true, active: true, position: 5)
    colors.create(value: "333ecf", default: true, active: true, position: 6)
  end

  def add_default_nickname
    update(nickname: customer.nickname)
  end

  def add_improver_act_types
    ActTypeSetting.create!(customer_setting_id: id, by_default: true, activated: true,
                           color: "#65BAF8", label: "preventive")
    ActTypeSetting.create!(customer_setting_id: id, by_default: true, activated: true,
                           color: "#DD8CB7", label: "corrective")
    ActTypeSetting.create!(customer_setting_id: id, by_default: true, activated: true,
                           color: "#B0C64B", label: "improvement")

    ActVerifTypeSetting.create!(customer_setting_id: id, by_default: true, activated: true,
                                color: "#6EDC6C", label: "control")
    ActVerifTypeSetting.create!(customer_setting_id: id, by_default: true, activated: true,
                                color: "#99E394", label: "audit")

    ActEvalTypeSetting.create!(customer_setting_id: id, by_default: true, activated: true,
                               color: "#A3A3A3", label: "indicator")
    ActEvalTypeSetting.create!(customer_setting_id: id, by_default: true, activated: true,
                               color: "#BABABA", label: "audit")
    ActEvalTypeSetting.create!(customer_setting_id: id, by_default: true, activated: true,
                               color: "#D1D1D1", label: "management_feedback")
    ActEvalTypeSetting.create!(customer_setting_id: id, by_default: true, activated: true,
                               color: "#E8E8E8", label: "customer_feedback")
  end

  def add_improver_act_domains
    improver_act_domains.create!(by_default: true, color: "#e89c30", activated: true, label: "quality")
    improver_act_domains.create!(by_default: true, color: "#f0bf72", activated: true, label: "security")
    improver_act_domains.create!(by_default: true, color: "#f4d49e", activated: true, label: "environment")
  end

  def add_improver_audit_settings
    AuditTypeSetting.create!(customer_setting_id: id, by_default: true, color: "#311d5c",
                             activated: true, label: "internal")
    AuditTypeSetting.create!(customer_setting_id: id, by_default: true, color: "#452882",
                             activated: true, label: "external")
    AuditTypeSetting.create!(customer_setting_id: id, by_default: true, color: "#5934a7",
                             activated: true, label: "certification")
    AuditTypeSetting.create!(customer_setting_id: id, by_default: true, color: "#6a3fc4",
                             activated: true, label: "diagnostic")
    AuditTypeSetting.create!(customer_setting_id: id, by_default: true, color: "#9197e5",
                             activated: true, label: "evaluation")

    AuditThemeSetting.create!(customer_setting_id: id, by_default: true, color: "#a1671e",
                              activated: true, label: "system")
    AuditThemeSetting.create!(customer_setting_id: id, by_default: true, color: "#cb8426",
                              activated: true, label: "process")
    AuditThemeSetting.create!(customer_setting_id: id, by_default: true, color: "#e89c30",
                              activated: true, label: "procedure")
    AuditThemeSetting.create!(customer_setting_id: id, by_default: true, color: "#f0bf72",
                              activated: true, label: "product")
    AuditThemeSetting.create!(customer_setting_id: id, by_default: true, color: "#f4d49e",
                              activated: true, label: "project")
  end

  def add_improver_event_causes
    improver_causes.create!(by_default: true, activated: true, label: "personal")
    improver_causes.create!(by_default: true, activated: true, label: "material")
    improver_causes.create!(by_default: true, activated: true, label: "machine")
    improver_causes.create!(by_default: true, activated: true, label: "method")
    improver_causes.create!(by_default: true, activated: true, label: "management")
    improver_causes.create!(by_default: true, activated: true, label: "environment")
  end

  def add_improver_event_domains
    improver_event_domains.create!(by_default: true, color: "#e89c30", activated: true, label: "quality")
    improver_event_domains.create!(by_default: true, color: "#f0bf72", activated: true, label: "security")
    improver_event_domains.create!(by_default: true, color: "#f4d49e", activated: true, label: "environment")
  end

  def add_improver_event_types
    improver_types.create!(by_default: true, color: "#311d5c", activated: true, label: "non_compliance")
    improver_types.create!(by_default: true, color: "#452882", activated: true, label: "sensitive_point")
    improver_types.create!(by_default: true, color: "#5934a7", activated: true, label: "lead_of_improvement")
    improver_types.create!(by_default: true, color: "#6a3fc4", activated: true, label: "strong_point")
    improver_types.create!(by_default: true, color: "#9197e5", activated: true, label: "work_accident")
    improver_types.create!(by_default: true, color: "#ae97df", activated: true, label: "customer_complaint")
  end

  def add_improver_prefixes
    ReferenceSetting.create!(
      customer_setting: self,
      event_prefix: "EVE",
      act_prefix: "ACT",
      audit_prefix: "AUD"
    )
  end

  # rubocop:disable Metrics/MethodLength
  def add_pastilles
    pastilles.create!(customer_setting_id: id, label: "R", activated: true,
                      desc_en: "Responsable",
                      desc_fr: "Réalise",
                      desc_es: "Actor",
                      desc_de: "Zuständig",
                      custom: false,
                      color: "#31C1E6")
    pastilles.create!(customer_setting_id: id, label: "A", activated: true,
                      desc_en: "Accountable",
                      desc_fr: "Approuve",
                      desc_es: "Responsable",
                      desc_de: "Verantwortlich",
                      custom: false,
                      color: "#8DC73F")
    pastilles.create!(customer_setting_id: id, label: "C", activated: true,
                      desc_en: "Consulted",
                      desc_fr: "Consulté",
                      desc_es: "Consultor",
                      desc_de: "Konsultiert",
                      custom: false,
                      color: "#F8982A")
    pastilles.create!(customer_setting_id: id, label: "I", activated: true,
                      desc_en: "Informed",
                      desc_fr: "Informé",
                      desc_es: "Informado",
                      desc_de: "Informiert",
                      custom: false,
                      color: "#E062A0")
    pastilles.create!(customer_setting_id: id, label: "0", activated: true,
                      desc_en: "None",
                      desc_fr: "Aucun",
                      desc_es: "Ninguno",
                      desc_de: "Keine",
                      custom: false,
                      color: "#CFD0DA")
    pastilles.create!(customer_setting_id: id, label: "1", activated: true,
                      desc_en: "Unknown",
                      desc_fr: "Inconnu",
                      desc_es: "Desconocido",
                      desc_de: "Unbekannt",
                      custom: false,
                      color: "#363B4C")
    pastilles
  end
  # rubocop:enable Metrics/MethodLength

  # END required for a new record

  private

  def check_sso_settings
    return if sso_settings.present? && sso_settings.filled?

    errors.add(:authentication_strategy, I18n.t("settings.edit_sso.must_be_filled"))
  end

  def check_ldap_settings
    return if ldap_settings.enabled.any?

    errors.add(:authentication_strategy, I18n.t("settings.flash_msg_ldap.must_have_enabled_server"))
  end
end
