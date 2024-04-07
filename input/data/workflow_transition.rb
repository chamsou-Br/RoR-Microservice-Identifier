# frozen_string_literal: true

#
# Represents a transition in an entity's workflow from one state to another
#
class WorkflowTransition
  #
  # Enumerates the various availability options for a given workflow transition
  #
  module Availability
    extend Enumerable

    # A transition is **available** if it can be performed as is by the given
    # user.
    AVAILABLE = :available

    # A transition is **forbidden** if the requesting user is not authorized to
    # perform it.  This can often be changed by augmenting the privileges of the
    # requesting user.
    FORBIDDEN = :forbidden

    # A transition is **impossible** if it may never be performed.
    IMPOSSIBLE = :impossible

    # A transition is **unavailable** if some criteria have yet to be met to
    # make it available to the requesting user.
    UNAVAILABLE = :unavailable

    #
    # Enumerates through all the availability constants defined and their values
    #
    # @yieldparam [Symbol] key
    # @yieldparam [Symbol] value
    # @return [Enumerator]
    # @todo Extract to a generic `Enum` module or use a similar gem that uses
    #   constants defining key/values pairs.
    def self.each
      if block_given?
        constants.each { |key| yield key, const_get(key) }
      else
        to_enum(:each)
      end
    end

    #
    # Is the given value included in the enum's values?
    #
    # @param availability
    # @return [Boolean]
    # @todo Extract to a generic `Enum` module or use a similar gem that uses
    #   constants defining key/values pairs.
    def self.value?(availability)
      values.include?(availability)
    end

    #
    # @return [Array<Symbol>]
    # @todo Extract to a generic `Enum` module or use a similar gem that uses
    #   constants defining key/values pairs.
    def self.values
      map { |_, value| value }
    end

    #
    # Returns an appropriate availability from the given value
    #
    # @param availability
    # @return [Symbol]
    # @raise [ArgumentError] if the given value is not a valid availability
    def self.for(availability)
      unless availability.respond_to?(:to_sym) && value?(availability.to_sym)
        raise ArgumentError, "#{availability} is not a valid transition " \
                             "availability.  Use one of #{Availability.to_a}."
      end

      availability.to_sym
    end
  end

  def initialize(availability:,
                 key:,
                 name:,
                 admin_only: false,
                 justifications: [],
                 requires_comment: false,
                 weight: 0)
    @admin_only = admin_only.nil? ? false : admin_only
    @availability = Availability.for(availability)
    @justifications = justifications || []
    @key = key
    @name = name
    @requires_comment = requires_comment.nil? ? false : requires_comment
    @weight = weight || 0
  end

  #
  # Can the transition only be performed by administrators?
  #
  # @return [Boolean]
  attr_reader :admin_only

  #
  # The availability of a transition determines if a transition can be performed
  # currently, if it can be performed after some criteria are met, or if it is
  # impossible.
  #
  # @return [String, Symbol]
  attr_reader :availability

  #
  # Justifications include one or more reasons why a transition may or may not
  # be performed.
  #
  # @return [Array<String>]
  attr_reader :justifications

  #
  # A serialization-safe language-agnostic key by which to refer to the
  # transition
  #
  # @return [String]
  attr_reader :key

  #
  # A human-meaningful name for the transition
  #
  # @return [String]
  attr_reader :name

  #
  # Does the transition require a comment to be performed?
  #
  # @return [Boolean]
  attr_reader :requires_comment

  #
  # An arbitrary numerical value with which to _weigh_ a transition
  #
  # @return [Integer]
  attr_reader :weight

  alias admin_only? admin_only
  alias requires_comment? requires_comment
end
