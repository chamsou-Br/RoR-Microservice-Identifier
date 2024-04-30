# frozen_string_literal: true

# provides additional checks to ensure password policy
class PasswordPolicyValidator < ActiveModel::EachValidator
  # Password complexity restrictions
  # length is 10-100
  # at least one lowercase letter
  # at least one uppercase letter
  # at least one digit
  # at least one special character
  PASSWORD_FORMAT = /\A(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*?[[:^alnum:]]).{10,100}\z/.freeze

  def validate_each(record, _attribute, value)
    @user = record
    @new_password = value

    return if @user.errors[:password].any?
    return if @new_password.nil?

    should_comply_with_pwd_format
    should_not_be_previous_pwd if @user.persisted?
    should_not_be_login
    should_not_be_inverted_login
    should_not_contain_common_word
  end

  private

  def add_error_msg(i18n_last_key)
    @user.errors[:password] << I18n.t(
      ".activerecord.errors.models.user.attributes.password.#{i18n_last_key}"
    )
  end

  def should_comply_with_pwd_format
    return if PASSWORD_FORMAT.match?(@new_password)

    add_error_msg :format
  end

  def should_not_be_previous_pwd
    previous_pwd_enc = User.find(@user.id).encrypted_password
    bcrypt = ::BCrypt::Password.new(previous_pwd_enc)
    current_pwd_enc = ::BCrypt::Engine.hash_secret(
      [@new_password, Devise.pepper].join,
      bcrypt.salt
    )
    return unless current_pwd_enc == previous_pwd_enc

    add_error_msg :previous_pwd
  end

  def should_not_be_login
    return unless @new_password.casecmp(@user.email).zero?

    add_error_msg :not_login
  end

  def should_not_be_inverted_login
    return unless @new_password.casecmp(@user.email.reverse).zero?

    add_error_msg :not_reversed_login
  end

  def should_not_contain_common_word
    normalized_pwd = @new_password.downcase
    return unless COMMON_PASSWORDS.detect { |pwd| normalized_pwd == pwd }

    add_error_msg :dictionary
  end
end
