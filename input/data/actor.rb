# frozen_string_literal: true

# rubocop:disable Layout/LineLength: Line is too long. [126/120]

# == Schema Information
#
# Table name: actors
#
#  id               :integer          not null, primary key
#  user_id          :integer          not null
#  responsibility   :string(255)      not null
#  affiliation_type :string(255)
#  affiliation_id   :integer
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  module_level     :string(255)
#  model_level      :string(255)
#  app_level        :string(255)
#
# Indexes
#
#  index_actors_on_all_fields  (user_id,responsibility,module_level,model_level,affiliation_type,affiliation_id) UNIQUE
#

# rubocop:enable Layout/LineLength: Line is too long. [126/120]

# This class expresses the relationship of a given responsible, that is, a
# user, group or role,  with an object of affiliation_type via a named
# responsibility. A "responsible" can be "affiliated" to an entity (i.e. Event,
# Risk), or to a Customer for semi- and global responsibilities.
#
class Actor < ApplicationRecord
  belongs_to :responsible, polymorphic: true
  belongs_to :affiliation, polymorphic: true

  AFFILIATES = %w[Act Audit AuditElement Group Customer Event Opportunity
                  Risk User].freeze

  validates :affiliation_type, inclusion: { in: AFFILIATES }
  # Pending for use in Graph and Document.
  # validates :responsible_type, inclusion: { in: %w[Group Role User] }
  validates :responsible_type, inclusion: { in: %w[User] }
  validates :responsibility, :responsible, presence: true

  validate :responsibility_membership

  # TODO: this Rails validation can eventually impact the performance of the
  # app. Its counterpart in the DB, the existing unique index in the fields,
  # is a lot more efficient, however, is not very user friendly.
  # Following the discussion in #3177, !4118#note_114432, this comment is
  # added, as a layer in between can be added.
  #
  validates_uniqueness_of :responsible_id,
                          scope: %i[responsible_type responsibility
                                    module_level model_level
                                    affiliation_type affiliation_id]

  def full_responsibility
    return "#{model_level}_#{responsibility}" if model_level
    return "#{module_level}_#{responsibility}" if module_level
    return "#{app_level}_#{responsibility}" if app_level

    responsibility
  end

  def responsibility_membership
    # If not a customer, affiliation is enough for actor to be valid.
    return true unless affiliation_type == "Customer"

    # Record is valid if one and only one of the three has a value
    return true if [model_level, module_level, app_level].one?

    errors[:base] << "One of model or module or app_level must be specified, "\
                     "if affiliated to a customer."
  end
end
