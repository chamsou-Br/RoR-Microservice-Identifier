# frozen_string_literal: true

class Iam::ActorValidation
  def initialize(record: nil, customer: nil)
    if record
      @target = record
      @responsibilities = Rails.configuration.responsibilities.dig(
        "entity", @target.class.to_s.underscore, "responsibilities"
      )
    elsif customer
      @target = customer
      @module_level_info = Rails.configuration.responsibilities["module_level"]
    end
  end

  def validate
    # Nothing to do here if record does not implement actors
    return unless @target.respond_to?(:actors)

    # Nothing to do here if there are no responsibilities
    return unless @responsibilities.any?

    # Verify if the responsibility_name exists for that target
    validate_responsibility_name unless @module_level || @model_level

    # Find the responsibility names that are required
    required_responsibilities = @responsibilities.select do |_key, value|
      value["required"]
    end

    # Separate the two types of required responsibilities between singular
    # and plural
    required_sing, required_plural =
      required_responsibilities.partition do |_key, value|
        value["singular"]
      end

    validate_singular(required_sing)
    validate_plural(required_plural)
  end

  # This method ensures that there is a method in the @target for each of the
  # modules named in the config, to verify if @target has access to that said
  # module.
  #
  def validate_module
    current_modules = @module_level_info.keys.select do |key|
      @target.send("#{key}?")
    end
    return true if current_modules.empty?

    current_modules.each do |pyx4_module|
      @responsibilities = @module_level_info[pyx4_module]["responsibilities"]
      @module_level = pyx4_module
      validate

      @module_level_info[pyx4_module]["models"]
        .each do |model_name, model_level_config|
          @responsibilities = model_level_config["responsibilities"]
          @model_level = model_name
          validate
        end
    end
  end

  def validate_responsibility_name
    @target.actors.map(&:responsibility).each do |responsibility_name|
      next if @responsibilities.include? responsibility_name

      @target.errors.add(
        :actors, message: "#{@target.class} does not have a responsibility " +
                          full_responsibility_name(responsibility_name)
      )
    end
  end

  def validate_singular(required_sing)
    required_sing.to_h.each_key do |responsibility_name|
      # Count that there is only one actor for singular required responsibility
      #
      responsibility_name_count = @target.actors.count do |actor|
        actor.responsibility == responsibility_name
      end
      next if responsibility_name_count == 1

      @target.errors.add(
        :actors,
        message: "#{@target.class} must have one "\
                 "#{full_responsibility_name(responsibility_name)}"
      )
    end
  end

  def validate_plural(required_plural)
    required_plural.to_h.each_key do |responsibility_name|
      # Find at least one actor with that responsibility
      #
      next if @target.actors.detect do |actor|
        actor.responsibility == responsibility_name
      end

      @target.errors.add(
        :actors, message: "#{@target.class} must have a least one " +
                          full_responsibility_name(responsibility_name)
      )
    end
  end

  private

  # Returns the full name of the given responsibility depending on the
  # `@module_level` and `@model_level` instance variables.
  #
  # @example
  # full_responsibility_name("owner") # "owner"
  # full_responsibility_name("owner") # "risk_owner" with @model_level "risk"
  # full_responsibility_name("user") # "risk_module_user" with
  #   @module_level "risk_module"
  #
  def full_responsibility_name(responsibility_name)
    if @model_level
      "#{@model_level}_#{responsibility_name}"
    elsif @module_level
      "#{@module_level}_#{responsibility_name}"
    else
      responsibility_name
    end
  end
end
