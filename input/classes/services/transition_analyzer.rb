# frozen_string_literal: true

# This class analyzes the problems there might be with transitions.
# This is WIP.
#
class TransitionAnalyzer
  def initialize(entity, user)
    @entity = entity
    @user = user
    @pre_path = "#{@entity.class.to_s.underscore}.refuse_transition"
    @reasons = []
  end

  def analyze_event
    if @entity.under_analysis?
      when_under_analysis
    else
      []
    end
  end

  def when_under_analysis
    # Commenting certain checks and tips to replicate improver2 behavior.
    # Later this refactor will be fruitful when needing analyzing other states.
    # rubocop:disable Style/IfUnlessModifier
    #
    unless @entity.required_analysis_fields?
      @reasons << ["#{@pre_path}.missing_analysis_fields"]
    end
    # rubocop:enable Style/IfUnlessModifier

    @reasons << ["#{@pre_path}.not_owner"] unless @entity.owner == @user

    [ # check_ask_approval,
      # check_ask_closure_approval,
      check_start_processing,
      check_close_event
    ].compact
  end

  def check_ask_approval
    return if @entity.can_ask_approval?

    { name: "ask_approval",
      reasons: ([cim_mode, actions] + @reasons).compact.uniq }
  end

  def check_ask_closure_approval
    return if @entity.can_ask_closure_approval?

    { name: "ask_closure_approval",
      reasons: ([cim_mode, no_actions] + @reasons).compact.uniq }
  end

  def check_start_processing
    return if @entity.can_start_processing?

    { name: "start_processing",
      reasons: ([no_cim_mode, actions] + @reasons).compact.uniq }
  end

  def check_close_event
    return if @entity.can_close_event?

    { name: "close_event",
      reasons: ([no_cim_mode, no_actions] + @reasons).compact.uniq }
  end

  def cim_mode
    "#{@pre_path}.not_cim_mode" unless @entity.cim_mode?
  end

  def actions
    "#{@pre_path}.no_actions" unless @entity.actions?
  end

  def no_actions
    "#{@pre_path}.open_actions" if @entity.actions?
  end

  def no_cim_mode
    "#{@pre_path}.cim_mode" if @entity.cim_mode?
  end
end
