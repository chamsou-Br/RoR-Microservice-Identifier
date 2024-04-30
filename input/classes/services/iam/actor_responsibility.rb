# frozen_string_literal: true

# This service sets up the actor_responsibility service. It establishes the
# relationship between actors and responsibilities depending on the entity and
# the customer, and creates the appropriate methods for querying and mutating
# such relationships.
#
# Part of the name of a generated method is the responsibility name, defined
# for each level in the file `config/responsibilities.yml`.
#
# A level can be an entity (i.e. a risk instance), a model (usually a
# class, i.e. Risk), and a pyx4 module (i.e. risk_module, improver).
#
# Another part of the responsibility name is the level it belongs to. This
# disambiguation is needed because there might be a responsibility at two
# different levels: for example, a risk instance can have a cim, and the Risk
# can have designated cims.
#
# The name for the generated method will include the level and the
# responsibility, except for the entity responsibilities.
#
class Iam::ActorResponsibility
  def initialize(record: nil, customer: nil)
    if record
      # Sets up the methods at the entity level
      @target = record
      setup_for_entity
    elsif customer
      # Sets up the method at the customer level: model_level and module_level
      @target = customer
      setup_for_model_level
      setup_for_module_level
      setup_for_app_level
    else
      "Nothing to do here"
    end
  end

  # When an entity includes this service, this method is needed to create the
  # necessary methods of responsibility management, according the to
  # configuration in `config/responsibilities.yml`
  #
  def setup_for_entity
    raise ArgumentError unless @target.respond_to?(:actors)

    self.class.attr_reader :entity_responsibilites
    record_name = @target.class.to_s.underscore

    # Hash containing as keys the entities and as value a hash of the form:
    # "responsibilities" => { responsibility_name: responsibility_specs }
    #
    entities_config = Rails.configuration.responsibilities["entity"]

    # Find the possible responsibilities this entity can have
    level_config = entities_config[record_name]["responsibilities"]
    entity_responsibilities = level_config.keys
    return unless entity_responsibilities.any?

    # Needed for now for the attr_reader
    @entity_responsibilites = entity_responsibilities
    responsibilities = entity_responsibilities

    params = { responsibilities: responsibilities,
               level_config: level_config }

    ## method creators
    responsibility_readers(params)
    responsibility_writers(params)
    user_in_responsibility(params)
    #  responsibility_x_in(user) # bool
    #  users_responsibility_x # list of users
    #  responsibility_of_user_in(user) # responsibility name or nil
  end

  # This method is run when the Customer is initialized, as the Customer model
  # always includes the service. Running this method is needed to create the
  # necessary responsibility management methods at the model_level and
  # according to the configuration in `config/responsibilities.yml`
  #
  def setup_for_model_level
    # Hash containing as keys the responsible classes and as value a hash as:
    # "responsibilities" => { responsibility_name: responsibility_specs }
    #
    models_config = Rails.configuration.responsibilities["model_level"]
    models = models_config.keys

    # Iterate through the models found in the models_config to create methods
    #
    models.each do |model_name|
      level_config = models_config[model_name]["responsibilities"]
      model_responsibilities = level_config.keys

      params = { responsibilities: model_responsibilities,
                 level_config: level_config,
                 prefix: "#{model_name}_",
                 model_level: model_name }

      responsibility_readers(params)
      responsibility_writers(params)
      user_in_responsibility(params)
    end
  end

  # This method is run when the Customer is initialized, as the Customer model
  # always includes the service. Running this method is needed to create the
  # necessary responsibility management methods at the module_level
  # and according to the configuration in `config/responsibilities.yml`
  # At the moment of writing, only the `instance_owner` is defined.
  #
  def setup_for_module_level
    # Hash containing as keys the pyx4 modules and as value a hash of the form:
    # "responsibilities" => { responsibility_name: responsibility_specs }
    #
    modules_config = Rails.configuration.responsibilities["module_level"]
    modules = modules_config.keys

    # Iterate through the modules to create methods
    #
    modules.each do |module_level|
      level_config = modules_config[module_level]["responsibilities"]
      module_level_responsibilities = level_config.keys

      params = { responsibilities: module_level_responsibilities,
                 level_config: level_config,
                 prefix: "#{module_level}_",
                 module_level: module_level }

      responsibility_readers(params)
      responsibility_writers(params)
      user_in_responsibility(params)
    end
  end

  # This method is run when the Customer is initialized, as the Customer model
  # always includes the service. Running this method is needed to create the
  # necessary responsibility management methods at the app_level
  # and according to the configuration in `config/responsibilities.yml`
  #
  def setup_for_app_level
    # Hash containing as keys the pyx4 modules and as value a hash of the form:
    # "responsibilities" => { responsibility_name: responsibility_specs }
    #
    app_config = Rails.configuration.responsibilities["app_level"]

    app_config.each_key do |app_level|
      level_config = app_config[app_level]["responsibilities"]
      app_level_responsibilities = level_config.keys

      params = { responsibilities: app_level_responsibilities,
                 level_config: level_config,
                 prefix: "#{app_level}_",
                 app_level: app_level }

      responsibility_readers(params)
      responsibility_writers(params)
      user_in_responsibility(params)
    end
  end

  # TODO: get rid of these problems when adjusting to Roles and Groups.
  # rubocop:disable Metrics/CyclomaticComplexity, Metrics/MethodLength
  # rubocop:disable Metrics/PerceivedComplexity
  #
  # Creates the methods to return the users with a responsibility in the level
  # (i.e. entity, model_level or module_level). On success, if responsibility is
  # singular, the created method returns a User, otherwise an array of User.
  #
  # @note Generated methods names are `responsibility[s]`.
  #
  # @!macro [attach] iam.responsibility_readers
  #   @example
  #     service.owner
  #     @return [User]
  #
  #     service.cims
  #     @return [Array<User>]
  #
  def responsibility_readers(
    responsibilities:, level_config:, prefix: nil,
    model_level: nil, module_level: nil, app_level: nil
  )
    # @return [Array, Array<User>] User or users with that responsibility
    # TODO: this is now returning a polymorphic responsible, which can be
    # either a User, Group or Role.
    # TODO: adjust when not User.
    #
    responsibilities.each do |responsibility|
      actor_params = { responsibility: responsibility,
                       model_level: model_level,
                       module_level: module_level,
                       app_level: app_level,
                       affiliation_type: @target.class.to_s }
      # @target.id does not have a value yet in the actor_params assignment.
      # Therefore the assignment needs to be done in the method definition.
      if level_config.dig(responsibility, "singular")
        define_singleton_method("#{prefix}#{responsibility}") do
          responsible = Actor.find_by(
            actor_params.merge(affiliation_id: @target.id)
          )&.responsible

          # TODO: handle when Group or Role
          return responsible if responsible.instance_of?(User)
        end
      else
        define_singleton_method("#{prefix}#{responsibility}s") do
          responsibles = Actor.where(
            actor_params.merge(affiliation_id: @target.id)
          ).map(&:responsible)

          # TODO: handle when Group or Role
          only_users = responsibles.map(&:class).uniq
          only_users == [User] ? responsibles : []
        end
      end
    end
  end
  # rubocop:enable Metrics/PerceivedComplexity
  # rubocop:enable Metrics/CyclomaticComplexity, Metrics/MethodLength

  # Writer methods can either set, add, replace or remove actor's
  # responsibilities, depending on whether they are plural or singular. This
  # method will farm out to the correct method creators and using `params`.
  #
  # @param [Hash] params Part of the config needed to farm out to creator method
  #
  def responsibility_writers(params)
    params[:responsibilities].each do |responsibility|
      actor_params = { responsibility: responsibility,
                       model_level: params[:model_level],
                       module_level: params[:module_level],
                       app_level: params[:app_level] }
      method_to_be = "#{params[:prefix]}#{responsibility}"

      if params.dig(:level_config, responsibility, "singular")
        set_responsibility(actor_params, "#{method_to_be}=")
      else
        replace_responsibilities(actor_params, "#{method_to_be}s=")
        add_responsibilities(actor_params, "add_#{method_to_be}s".to_sym)
        add_responsibility(actor_params, "add_#{method_to_be}".to_sym)
        remove_responsibility(actor_params, "remove_#{method_to_be}".to_sym)
      end
    end
  end

  #
  # TODO: this is now returning a polymorphic responsible, which can be
  # either a User, Group or Role.
  # TODO: adjust when not User.
  # Creates a method to set or unset the user assigned to a responsibility.
  #
  # @param [Hash] actor_params The parameters needed to create the method
  # @param [String] method_name The name of the new method calculated when
  #   called, built according to the level and nature of method.
  #
  # @note Used only for singular responsibilities. The generated method name is
  #   `responsibility=`.
  #
  # @!macro [attach] iam.set_responsibility
  #   @!method $2
  #
  #   Sets or unsets the user assigned to the responsibility
  #
  #   @example
  #     service.owner = user
  #     service.owner = nil
  #
  def set_responsibility(actor_params, method_name)
    # @param [User, nil] user The user to assign or nil to unset the user.
    # @return [User, nil] the given user
    #
    define_singleton_method(method_name) do |user|
      actors_to_delete = @target.actors.where(actor_params)
      @target.actors.delete(actors_to_delete)

      # For now assuming that is been done just to User.
      # TODO: adjust to Group and Role
      #
      @target.actors << Actor.new(actor_params.merge(responsible: user)) if user
      user
    end
  end

  # Creates methods to replace all the users with that responsibility by the
  # list of users provided as argument. Used for plural responsibilities.
  #
  # @param [Hash] actor_params The parameters needed to create the method
  # @param [String] method_name The name of the new method calculated when
  #   called, built according to the level and nature of method.
  #
  # @note Generated methods names are `responsibilities=`.
  #
  # @!macro [attach] iam.replace_responsibilities
  #   @!method $2
  #
  #   Replaces the users for that responsibility, does nothing when array of
  #     users is empty.
  #
  #   @example
  #     service.validators = users
  #
  def replace_responsibilities(actor_params, method_name)
    # TODO: adjust to polymorphic `Responsible`.
    #
    # @example service.risk_cims=users
    # @param [Array<User>] users The users to assign or nil to unset the user.
    # @return [Array<User>] The users
    #
    define_singleton_method(method_name) do |users|
      actors_to_remove = @target.actors.where(actor_params)
      @target.actors.delete(actors_to_remove)

      return [] unless users

      if @target.actors << users.map do |user|
           Actor.new(actor_params.merge(responsible: user))
         end
        users
      end
    end
  end

  # Creates methods to add the user provided by as argument to the
  # responsibility of the level. Used for plural responsibilities.
  #
  # @param [Hash] actor_params The parameters needed to create the method
  # @param [String] method_name The name of the new method calculated when
  #   called, built according to the level and nature of method.
  #
  # @note Generated methods names are `add_responsibility`.
  #
  # @!macro [attach] iam.add_responsibility
  #   @!method $2
  #
  #   Adds the user for that responsibility, does nothing in nil.
  #
  #   @example
  #     service.add_risk_module_admin(user)
  #
  def add_responsibility(actor_params, method_name)
    # @example service.add_risk_module_admin(user)
    #
    # @param [User] user The user to add
    # @return [User] The added user
    #
    define_singleton_method(method_name) do |user|
      # TODO: Adjust when Role or Group?
      #
      return unless user.instance_of?(User)

      # rubocop:disable Style/IfUnlessModifier
      if @target.actors << Actor.new(actor_params.merge(responsible: user))
        user
      end
      # rubocop:enable Style/IfUnlessModifier
    end
  end

  # Creates a method to unassign the user from a given responsibility.
  # Used for plural responsibilities.
  #
  # @param [Hash] actor_params The parameters needed to create the method
  # @param [String] method_name The name of the new method calculated when
  #   called, build according to the level and nature of method.
  #
  # @note Generated methods names are `remove_responsibility`.
  #
  # @!macro [attach] iam.remove_responsibility
  #   @!method $2
  #
  #   Removes the user from that responsibility.
  #
  #   @example
  #     service.remove_validator(user)
  #
  def remove_responsibility(actor_params, method_name)
    # @example service.remove_validator(user)
    #
    # @param [User] user The user to remove
    # @return [Boolean] Indicate if the actor was removed or not
    #
    define_singleton_method(method_name) do |user|
      actors_to_remove = @target.actors
                                .where(actor_params.merge(responsible: user))

      @target.actors.delete(actors_to_remove).any?
    end
  end

  # Creates methods to add the users provided by as argument to the
  # responsibility of the level. Used for plural responsibilities.
  #
  # @param [Hash] actor_params The parameters needed to create the method
  # @param [String] method_name The name of the new method calculated when
  #   called, build according to the level and nature of method.
  #
  # @note Generated methods names are `add_responsibilities`.
  #
  # @!macro [attach] iam.add_responsibilities
  #   @!method $2
  #
  #   Add the user for that responsibility.
  #
  #   @example
  #     service.add_risk_module_admins(users)
  #
  def add_responsibilities(actor_params, method_name)
    # @example service.add_risk_module_admins(users)
    #
    # @param [User] users The users to be added
    # @return [User] The added users
    #
    define_singleton_method(method_name) do |users|
      if @target.actors << users.map do |user|
           # TODO: Adjust when Role or Group
           next unless user.instance_of?(User)

           Actor.new(actor_params.merge(responsible: user))
         end
        users
      end
    end
  end

  # Creates methods to verify if a user has a responsibility
  # at the specified level.
  #
  # @note Generated methods names are `responsibility?`.
  #
  # @param [Hash] params The parameters needed to create the method
  #
  # @!macro [attach] iam.user_in_responsibility
  #   Verifies that user has that responsibility
  #
  #   @example
  #     service.author?(user)
  #     service.risk_module_admin?(user)
  #
  def user_in_responsibility(params)
    # @example service.author?(user)
    #          service.risk_module_admin?(user)
    #
    # @param [User]
    # @return [Bool]
    #
    params[:responsibilities].each do |responsibility|
      method_name = "#{params[:prefix]}#{responsibility}?"

      define_singleton_method(method_name) do |user|
        return false unless user.instance_of?(User)

        Actor.where(
          module_level: params[:module_level],
          model_level: params[:model_level],
          responsibility: responsibility,
          affiliation_id: @target.id,
          affiliation_type: @target.class.to_s,
          responsible_id: user.id
        ).any?
      end
    end
  end
end
