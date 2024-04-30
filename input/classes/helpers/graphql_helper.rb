# frozen_string_literal: true

module GraphqlHelper
  ##
  # Return a GraphQL error that contains in `extentions` the given error `code`
  # and messages.
  #
  # @param code [Symbol] the error code (defined in Enums::ErrorCodeEnum)
  # @param messages [Array<String>, String] one or multiple translated messages
  #
  # @return [GraphQL::ExecutionError]
  #   the error used to populate the `errors` in GraphQL response
  #
  # @raise [ArgumentError]
  #   if the given code is not defined in `Enums::ErrorCodeEnum`
  #
  # rubocop: disable Style/IfUnlessModifier
  def graphql_error(code, messages)
    unless Enums::ErrorCodeEnum.values.key?(code.to_s)
      raise ArgumentError, "Undeclared GraphQL error code: #{code}"
    end

    messages = [messages] if messages.is_a?(String)

    GraphQL::ExecutionError.new(
      code.to_s.humanize,
      extensions: { code: code, messages: messages }
    )
  end
  # rubocop: enable Style/IfUnlessModifier

  ##
  # Raise a GraphQL error that contains in `extentions` the given error `code`
  # and messages.
  #
  # @see graphql_error
  #
  # @param code [Symbol] the error code (defined in Enums::ErrorCodeEnum)
  # @param messages [Array<String>, String] one or multiple translated messages
  #
  # @raise [GraphQL::ExecutionError]
  #   the error used to populate the `errors` in GraphQL response
  #
  def graphql_error!(code, messages)
    raise graphql_error(code, messages)
  end
end
