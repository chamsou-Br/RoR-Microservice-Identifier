# frozen_string_literal: true

class TagsController < ApplicationController
  include TagsHelper

  def index
    query = params[:q]
    respond_to do |format|
      format.json do
        render json: current_customer.tags.autocompleter(query)
      end
      format.html do
        tag = current_customer.tags.order(label: :asc).first
        if tag.nil?
          render
        else
          redirect_to tag_path(tag)
        end
      end
    end
  end

  def show
    @tag = current_customer.tags.find_by_id(params[:id])
    @graphs = @tag.graphs.select { |g| GraphPolicy.viewable?(current_user, g) && !g.in_archives? }
    @documents = @tag.documents.select { |d| DocumentPolicy.viewable?(current_user, d) && !d.in_archives? }
    respond_to do |format|
      format.html {}
    end
  end

  def new
    @tag = Tag.new
  end

  def create
    @tag = Tag.create(label: params[:tag][:label], customer_id: current_customer.id)
    if @tag.save
      flash[:success] = I18n.t("controllers.tags.successes.create")
    else
      flash[:error] = I18n.t("controllers.tags.errors.create")
      respond_to do |format|
        format.js { render :error_create, status: :unprocessable_entity }
      end
    end
  end

  def confirm_rename
    @tag = current_customer.tags.find(params[:id])
  end

  def rename
    @tag = current_customer.tags.find(params[:id])
    @tag.label = params[:label]
    if @tag.save
      flash.now[:success] = I18n.t("controllers.tags.successes.rename")
    else
      fill_errors_hash(I18n.t("controllers.tags.errors.rename"), @tag)
    end
  end

  def confirm_delete; end

  def delete
    @tag = current_customer.tags.find(params[:id])
    if @tag.destroy
      flash[:success] = I18n.t("controllers.tags.successes.delete")
    else
      flash[:error] = I18n.t("controllers.tags.errors.delete")
    end
    if current_customer.tags.empty?
      redirect_to tags_path
    else
      redirect_to tag_path(current_customer.tags.order(label: :asc).first)
    end
  end
end
