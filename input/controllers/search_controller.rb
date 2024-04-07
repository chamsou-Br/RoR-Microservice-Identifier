# frozen_string_literal: true

class SearchController < ApplicationController
  include Listable

  before_action :save_term

  def all
    respond_to do |format|
      format.json do
        render_list "header", :list_header_definition, properties: true
      end
    end
  end

  def header
    render partial: "header/search"
  end

  def improver_header
    # do improver search stuff here
    options = { size: 3 }
    @term = params[:term]
    @audits = Audit.search(@term, current_user,
                           { must: [{ terms: { _id: policy_scope(Audit).pluck(:id) } }] },
                           options).records
    @acts = Act.search(@term, current_user,
                       { must: [{ terms: { _id: policy_scope(Act).pluck(:id) } }] },
                       options).records
    @events = Event.search(@term, current_user,
                           { must: [{ terms: { _id: policy_scope(Event).pluck(:id) } }] },
                           options).records
    @groups = Group.search(@term, current_customer, {}, options).records
    @users = User.search(@term, current_user, {}, options).records
  end

  def graph
    query = Graph.search(@term, current_user, current_customer, {})
    @graph = query.paginate(page: params[:page] || 1, per_page: 20).records
    @total = query.results.total
  end

  def document
    query = Document.search(@term, current_user, current_customer, {}, size: 20)
    @document = query.paginate(page: params[:page] || 1, per_page: 20).records
    @total = query.results.total
  end

  def directory
    query = Directory.search(@term, current_customer, {}, size: 20)
    @directory = query.paginate(page: params[:page] || 1, per_page: 20).records
    @total = query.results.total
  end

  def role
    query = Role.search(@term, current_user, {}, size: 20)
    @role = query.paginate(page: params[:page] || 1, per_page: 20).records
    @total = query.results.total
  end

  def resource
    query = Resource.search(@term, current_user, {}, size: 20)
    @resource = query.paginate(page: params[:page] || 1, per_page: 20).records
    @total = query.results.total
  end

  def tag
    query = Tag.search(@term, current_customer, {}, size: 20)
    @tag = query.paginate(page: params[:page] || 1, per_page: 20).records
    @total = query.results.total
  end

  def user
    query = User.search(@term, current_user, {}, size: 20)
    @user = query.paginate(page: params[:page] || 1, per_page: 20).records
    @total = query.results.total
  end

  def group
    query = Group.search(@term, current_customer, {}, size: 20)
    @group = query.paginate(page: params[:page] || 1, per_page: 20).records
    @total = query.results.total
  end

  private

  def save_term
    @term = (params[:term].nil? ? "" : params[:term])
  end

  # TODO: Perhaps move some instance variable setting into private methods
  # rubocop:disable Metrics/AbcSize
  def list_header_definition
    size = { size: 3 }
    @graphs = Graph.search(@term, current_user, current_customer, {}, size).records
    @documents = Document.search(@term, current_user, current_customer, {}, size).records
    @roles = Role.search(@term, current_user, {}, size).records
    @resources = Resource.search(@term, current_user, {}, size).records
    @groups = Group.search(@term, current_customer, {}, size).records
    @users = User.search(@term, current_user, {}, size).records
    @tags = Tag.search(@term, current_customer, {}, size).records
    @directories = Directory.search(@term, current_customer, {}, size).records
    {
      items: lambda {
        @graphs + @documents + @roles + @resources + @groups + @users + @tags + @directories
      },
      search: ->(items, _term) { items }
    }
  end
  # rubocop:enable Metrics/AbcSize
end
