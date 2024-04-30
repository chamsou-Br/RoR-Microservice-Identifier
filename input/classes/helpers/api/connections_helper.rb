# frozen_string_literal: true

module Api::ConnectionsHelper
  def build_accept_link(connection)
    build_generic_link(connection, true)
  end

  def build_reject_link(connection)
    build_generic_link(connection, false)
  end

  private

  def build_generic_link(connection, accept)
    host = connection.connection.absolute_domain_name
    link = respond_invitation_store_connection_path(connection.customer_id)
    key = Rails.application.secrets.secret_key_base
    crypt = ActiveSupport::MessageEncryptor.new(key[0, 32], key)
    token = crypt.encrypt_and_sign(accept: accept, customer_id: connection.connection.id)
    "#{host}#{link}?token=#{token}"
  end
end
