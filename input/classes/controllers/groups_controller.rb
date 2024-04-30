# frozen_string_literal: true

class GroupsController < ApplicationController
  include Listable
  include UserAssignable

  before_action :find_group, except: %i[rename rename_modal]

  ##
  # Depending of the requested format, this function:
  # - html: renders the `groups/index` html view
  # - json: returns the values of the list of groups
  #
  def index
    respond_to do |format|
      format.html {}
      format.json { render_list "index", :list_index_definition }
    end
  end

  def new
    @group = Group.new
  end

  def create
    @group = current_customer.groups.new(group_params)
    authorize @group, :action_group?
    flash_x_success I18n.t("controllers.groups.successes.create") if @group.save
  end

  ##
  # Delete groups that are seleted in the list of groups
  #
  # TODO: This needs simplification, perhaps moving error handling out
  # rubocop:disable Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
  # rubocop:disable Metrics/AbcSize
  #
  def delete
    groups = list_selection(:list_index_definition)
    groups.each { |g| authorize g, :action_group? }
    begin
      count = groups.count
      if groups && current_customer.groups.destroy(groups)
        flash_x_success(I18n.t("controllers.groups.successes.delete", count: count))
        @reload = true
      end
    rescue StandardError
      if groups.any?
        group_linked_error = nil
        groups.each do |group|
          if group.errors[:group_linked].any?
            group_linked_error = group.errors[:group_linked]
            break
          end
        end

        if group_linked_error
          flash_x_error(group_linked_error.first)
        else
          flash_x_error(I18n.t("controllers.groups.errors.delete", count: groups.count))
        end
      else
        flash_x_error(I18n.t("controllers.groups.errors.delete"))
      end
      @reload = false
    end
  end
  # rubocop:enable Metrics/AbcSize
  # rubocop:enable Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

  def update
    authorize @group, :action_group?
    update_successful = @group.update_attributes(group_params)

    flash[:errors] = fix_flash_message(@group) unless update_successful

    respond_with_bip(@group)
  end

  private

  def find_group
    id = params[:id] || params[:group_id]
    @group = current_customer.groups.find(id) if id
  end

  def group_params
    params.require(:group).permit(:title, :description)
  end

  # This method is created simply to give backwards compatibility when a group
  # is not authorized, to return the same error code as expected in the tests.
  # This controller will be completely deprecated once the new user_module is
  # fully implemented.
  #
  def user_not_authorized
    flash_x_error I18n.t("errors.operation_failed"), :method_not_allowed
  end

  # TODO: this seems unused
  def list_items_show(term = "", _klass = "")
    users = @group.users
    unless term.empty?
      size = current_customer.users.count
      users = User.search(term, current_user, {}, size: size).records.where(id: users)
    end
    users
  end

  # TODO: this seems unused
  def list_orders_show
    { title: ->(users) { users.order("lastname") } }
  end

  # TODO: this seems unused
  def list_items_add(term = "", _klass = "")
    users = current_customer.users.where.not(id: @group.users)
    unless term.empty?
      size = current_customer.users.count
      users = User.search(term, current_user, {}, size: size).records.where(id: users)
    end
    users
  end

  # TODO: this seems unused
  def list_orders_add
    list_orders_show
  end

  # @see Listable concern about list definitions
  def list_index_definition
    {
      items: -> { policy_scope(Group) },
      search: lambda do |_groups, term|
        Group.search_list(term, current_customer).records
      end,
      tabs: {
        mygroups: ->(groups) { groups.where(id: current_user.groups) },
        all: ->(groups) { groups }
      },
      orders: {
        title: ->(groups) { groups.order("title") },
        title_inv: ->(groups) { groups.order("title DESC") },
        updated: ->(groups) { groups.order("updated_at DESC, title") }
      }
    }
  end
end
