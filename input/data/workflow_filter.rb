# frozen_string_literal: true

# Refactor `WorkflowFilter` by simplifying a number of case and chained ifs
class WorkflowFilter
  extend ActiveModel::Naming
  include ActiveModel::Model

  attr_accessor :term, :order_by

  def self.orderings
    {
      title: 1,
      title_inv: 2,
      separator_container: -1,
      usersfst: 3,
      groupsfst: 4,
      rolesfst: 5,
      separator_privilege: -1,
      viewersfst: 6,
      verifiersfst: 7,
      approversfst: 8,
      publisherfst: 9
    }
  end

  def initialize(attributes = {})
    super attributes
    @order_by = WorkflowFilter.orderings[:usersfst] if attributes.nil? || attributes[:order_by].blank?
    @order_by = @order_by.to_i
    @items = {}
  end

  #
  # @param [User] user
  #
  # TODO: Rename the following methods to use snake_case
  # rubocop:disable Naming/MethodName
  def appendFoundUser(user, viewer, verifier, approver, publisher)
    id = "user_#{user.id}"
    @items[id] ||= WorkflowElement.new(type: :user,
                                       object: user,
                                       title: user.name.full_inv,
                                       function: user.function,
                                       viewer: viewer,
                                       verifier: verifier,
                                       approver: approver,
                                       publisher: publisher)
  end

  def appendFoundGroup(group, viewer)
    id = "group_#{group.id}"
    @items[id] ||= WorkflowElement.new(type: :group,
                                       object: group,
                                       title: group.title,
                                       viewer: viewer)
  end

  def appendFoundRole(role, viewer)
    id = "role#{role.id}"
    @items[id] ||= WorkflowElement.new(type: :role,
                                       object: role,
                                       title: role.title,
                                       viewer: viewer)
  end

  def appendUserViewers(users)
    appendUsers(users, :viewer)
  end

  def appendUserVerifiers(users)
    appendUsers(users, :verifier)
  end

  def appendUserApprovers(users)
    appendUsers(users, :approver)
  end

  def appendUserPublisher(user)
    appendUsers([user], :publisher) if user.present?
  end

  def appendGroupViewers(groups)
    groups.each do |g|
      id = "group_#{g.id}"
      @items[id] ||= WorkflowElement.new(type: :group, object: g, title: g.title)
      @items[id].viewer = true
    end
  end

  def appendRoleViewers(roles)
    roles.each do |r|
      id = "role_#{r.id}"
      @items[id] ||= WorkflowElement.new(type: :role, object: r, title: r.title)
      @items[id].viewer = true
    end
  end
  # rubocop:enable Naming/MethodName

  # TODO: Refactor `apply` into smalled private methods
  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity
  # rubocop:disable Metrics/MethodLength, Metrics/PerceivedComplexity
  def apply
    values = @items.values
    return values if @term.present?

    case order_by
    when WorkflowFilter.orderings[:title]
      values.sort! { |x, y| x.title.downcase <=> y.title.downcase }
    when WorkflowFilter.orderings[:title_inv]
      values.sort! { |x, y| y.title.downcase <=> x.title.downcase }
    when WorkflowFilter.orderings[:usersfst]
      values.sort! { |x, y| sort_by_type_then_alpha(x, y, :user) }
    when WorkflowFilter.orderings[:groupsfst]
      values.sort! { |x, y| sort_by_type_then_alpha(x, y, :group) }
    when WorkflowFilter.orderings[:rolesfst]
      values.sort! { |x, y| sort_by_type_then_alpha(x, y, :role) }
    when WorkflowFilter.orderings[:viewersfst]
      values.sort! { |x, y| sort_by_privilege_then_alpha(x, y, :viewer) }
    when WorkflowFilter.orderings[:verifiersfst]
      values.sort! { |x, y| sort_by_privilege_then_alpha(x, y, :verifier) }
    when WorkflowFilter.orderings[:approversfst]
      values.sort! { |x, y| sort_by_privilege_then_alpha(x, y, :approver) }
    when WorkflowFilter.orderings[:publisherfst]
      values.sort! { |x, y| sort_by_privilege_then_alpha(x, y, :publisher) }
    end
    values
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity
  # rubocop:enable Metrics/MethodLength, Metrics/PerceivedComplexity

  private

  #
  # @param [Array<User>] users
  #
  # Rename `appendUsers` to `append_users`
  # rubocop:disable Naming/MethodName
  def appendUsers(users, privilege)
    users.each do |u|
      id = "user_#{u.id}"
      @items[id] ||= WorkflowElement.new(type: :user,
                                         object: u,
                                         title: u.name.full_inv,
                                         function: u.function)
      case privilege
      when :viewer then @items[id].viewer = true
      when :verifier then @items[id].verifier = true
      when :approver then @items[id].approver = true
      when :publisher then @items[id].publisher = true
      else raise "undefined privilege : <#{privilege}>"
      end
    end
  end
  # rubocop:enable Naming/MethodName

  # Rename parameters for `sort_by_type_then_alpha` and `sort_by_privilege_then_alpha`
  # rubocop:disable Naming/MethodParameterName
  def sort_by_type_then_alpha(x, y, type)
    if x.type == y.type
      x.title.downcase <=> y.title.downcase
    elsif x.type == type then -1
    elsif y.type == type then 1
    else x.type <=> y.type
    end
  end

  # TODO: Refactor `sort_by_privilege_then_alpha` by creating a comparator
  def sort_by_privilege_then_alpha(x, y, privilege)
    x_p = x.send(privilege)
    y_p = y.send(privilege)
    if x_p && y_p
      x.title.downcase <=> y.title.downcase
    elsif x_p then -1
    elsif y_p then 1
    else
      x_weight = privilege_weight(x)
      y_weight = privilege_weight(y)
      if x_weight == y_weight
        x.title.downcase <=> y.title.downcase
      else
        y_weight <=> x_weight
      end
    end
  end
  # rubocop:enable Naming/MethodParameterName

  def privilege_weight(obj)
    if obj.send(:viewer) then 1000
    elsif obj.send(:verifier) then 100
    elsif obj.send(:approver) then 10
    elsif obj.send(:publisher) then 1
    else 0
    end
  end
end
