# frozen_string_literal: true

class DashboardController < ApplicationController
  def index
    @graphs = policy_scope(Graph)
    @documents = policy_scope(Document)
    @roles = current_customer.roles
    @applicable_graphs = @graphs.latest_published(current_user, 5)
    @notifications = current_user.limite_notifications_by(20)
    @root_graph = current_customer.root_graph

    flash[:warning] = I18n.t("dashboard.index.no_owner") if ownerless?
  end

  private

  def ownerless?
    current_customer.owner.nil? && current_user.process_admin?
  end
end
