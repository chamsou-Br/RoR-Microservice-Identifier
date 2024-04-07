# frozen_string_literal: true

# == Schema Information
#
# Table name: involvables_roles
#
#  id              :integer          not null, primary key
#  involvable_id   :integer
#  involvable_type :string(255)
#  role            :integer          default("author"), not null
#  user_id         :integer
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  index_involvables_roles_on_involvable_type_and_involvable_id  (involvable_type,involvable_id)
#  index_involvables_roles_on_role                               (role)
#  index_involvables_roles_on_user_id                            (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#

# The class is responsible for maintaining connection between a User and an
# Involvable (ex: a Risk) in order to give a notion of a responsibility involved
#
class InvolvablesRole < ApplicationRecord
  belongs_to :involvable, polymorphic: true
  belongs_to :user

  enum responsibility: { author: 0,
                         owner: 1,
                         validator: 2,
                         cim: 3,
                         manager: 4,
                         contributor: 5,
                         admin: 6 }

  # validations
  validates :user, presence: true
end
