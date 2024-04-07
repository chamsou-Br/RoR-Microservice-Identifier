# frozen_string_literal: true

# == Schema Information
#
# Table name: super_admins
#
#  id                     :integer          not null, primary key
#  email                  :string(255)
#  encrypted_password     :string(255)      default(""), not null
#  reset_password_token   :string(255)
#  reset_password_sent_at :datetime
#  remember_created_at    :datetime
#  sign_in_count          :integer          default(0), not null
#  current_sign_in_at     :datetime
#  last_sign_in_at        :datetime
#  current_sign_in_ip     :string(255)
#  last_sign_in_ip        :string(255)
#  lastname               :string(255)
#  firstname              :string(255)
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#
# Indexes
#
#  index_super_admins_on_email                 (email) UNIQUE
#  index_super_admins_on_reset_password_token  (reset_password_token) UNIQUE
#

class SuperAdmin < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable

  validates :email, presence: true,
                    format: { is: true, with: email_regexp }

  include HumanNameable

  def self.find_for_authentication(conditions = {})
    logger.debug("find_for_super_admin_authentication")
    conditions.delete(:host) if conditions[:host].present?
    super
  end

  #
  # The full name of the super admin
  #
  # @return [String]
  # @deprecated Use {SuperAdmin#name} and {User::Name#full} instead.
  #
  def display_username
    "#{firstname} #{lastname}"
  end
end
