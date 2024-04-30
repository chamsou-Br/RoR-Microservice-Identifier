# frozen_string_literal: true

class ContributorsController < ApplicationController
  include Listable

  before_action :set_contributable

  def index
    @user = current_user
    logger.debug "--->contributors#index: #{params}"
    respond_to do |format|
      format.html { render layout: "container_partial" }
      format.json do
        @contributors = @contributable.contributors.to_a
        render_list "users/contributor", :list_index_definition
      end
    end
  end

  def create
    @user = current_customer.users.find(params[:id])

    begin
      # GraphPolicy#create_contributor? appears to check if the user is an
      # author and if the graph is `contribution_editable?` (state == "new")
      authorize @contributable, :create_contributor?

      @contributable.contributors << @user

      # We should not be sending a notification synchronously inline here.  The
      # new contributor receiving a notification is a side-effect of being added
      # as a contributor and should not determine the success or failure of this
      # action.
      # TODO: Defer sending the new contributor a notification to an
      #   asynchronous job
      NewNotification.create_and_deliver(
        customer: current_customer,
        category: :add_contributor,
        from: current_user,
        to: @user,
        entity: @contributable
      )
    rescue Pundit::NotAuthorizedError
      @contributable.errors.add :base, "can't add contributor"
      flash_x_error I18n.t("controllers.contributors.errors.create"), :method_not_allowed
    end
  end

  def destroy
    @user = current_customer.users.find params[:id]
    begin
      authorize @contributable, :remove_contributor?
      @contributable.contributors.delete @user
    rescue StandardError
      @contributable.errors.add :base, "can't remove contributor"
      flash_x_error I18n.t("controllers.contributors.errors.destroy"), :method_not_allowed
    end
  end

  private

  def set_contributable
    klass = [Graph, Event, Act, Audit].detect { |c| params[c.name.foreign_key.to_s] }
    @contributable = klass.find(params[klass.name.foreign_key.to_s])
  end

  def list_index_definition
    {
      items: -> { current_customer.users_list(false, true) },
      search: lambda do |_users, term|
        current_customer.users_list(false, true, User.search_list(term, current_user))
      end,
      tabs: {
        all: ->(users) { users },
        contibutors: ->(users) { users.where(id: @contributors) }
      },
      orders: {
        title: ->(users) { users.order("lastname") }
      }
    }
  end
end
