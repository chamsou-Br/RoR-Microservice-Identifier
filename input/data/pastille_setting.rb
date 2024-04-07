# frozen_string_literal: true

# == Schema Information
#
# Table name: pastille_settings
#
#  id                  :integer          not null, primary key
#  color               :string(255)
#  desc_en             :string(255)
#  desc_fr             :string(255)
#  desc_es             :string(255)
#  desc_de             :string(255)
#  label               :string(3)
#  activated           :boolean
#  customer_setting_id :integer
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  custom              :boolean          default(TRUE)
#
# Indexes
#
#  index_pastille_settings_on_customer_setting_id  (customer_setting_id)
#

# If we ever support a new language, this description set up must be revised;
# just adding a new attribute for the new language is not maintainable.
# Languge :nl is being faced out.
#
class PastilleSetting < ApplicationRecord
  belongs_to :customer_setting

  validates :desc_en, length: { maximum: 255 }
  validates :desc_fr, length: { maximum: 255 }
  validates :desc_es, length: { maximum: 255 }
  validates :desc_de, length: { maximum: 255 }

  validates :color, presence: true
  validates :label, presence: true,
                    length: { maximum: 3 },
                    uniqueness: { is: true,
                                  scope: %i[customer_setting_id activated],
                                  case_sensitive: false }

  validate :presence_desc_customer_language

  before_validation { |p| p.label = p.label&.upcase }

  # There are 6 initial pastille_settings created for any new customer. Four
  # known as RACI, which were to be ummutable but visible in the settings page,
  # and 2 vanilla, which are usually hidden, only available in the drop down
  # while editing the role of a shared task in a graph. The labels of these two
  # are "0" (None) and "1" (Unknown). (Their behaviour is unconventional
  # and will probably change.) All of these are created with `custom: false`.
  # The `default` scope gathers all the pastille_settings that are
  # `not_custom`, and `not_vanilla`, corresponding to the original RACI.
  #
  # NOTE: this scopes should be used on pastilles within the customer.settings.
  # Otherwise all of `custome` pastilles will be fetched, which is not what is
  # desired for the views.
  #
  scope :custom, -> { where(custom: true) }
  scope :not_custom, -> { where(custom: false) }
  scope :vanilla, -> { where(label: %w[0 1]) }
  scope :not_vanilla, -> { where.not(label: %w[0 1]) }
  scope :default, -> { not_custom.not_vanilla }

  # It is mandatory that a "responsability" have at least one description, the
  # check is done in the language of the customer.
  # TODO: The translation strings might need to change to specify that it must
  # be the customer's language.
  #
  def presence_desc_customer_language
    lang = customer_setting&.customer&.language

    if lang
      needed_desc = "desc_#{customer_setting.customer.language}"
      errors.add(needed_desc, :desc_needed) if self[needed_desc.to_s].blank?
    else
      errors.add(:base, "The customer's language must be defined")
    end
  end

  def label_for(_user)
    case label
    when "0" then ""
    when "1" then "?"
    else
      label
    end
  end

  def desc_for(user_or_customer)
    lang = user_or_customer.language || I18n.locale

    if lang
      send("desc_#{lang}")
    else
      ""
    end
  end
end
