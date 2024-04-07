# frozen_string_literal: true

# rubocop: disable all
class GroupdocumentsController < ApplicationController
  include ImproverNotifications

  def show
    # Le show retourne par défaut la version applicable si elle existe,
    # sinon, la last_available
    @document = current_customer.groupdocuments.find(params[:id]).applicable_version_or_last_available

    # redirect_to show_properties_document_path(@document)
    # respond_to do |format|
    #   format.json {
    #     unless DocumentPolicy.viewable?(current_user, @document)
    #       flash_x_error I18n.t('controllers.application.not_authorized')
    #     end
    #     render :json => {:properties => @document.to_json({:current_user => current_user}) }
    #   }
    #   format.html {
    #     redirect_to show_properties_document_path(@document)
    #   }
    # end
    if DocumentPolicy.viewable?(current_user, @document)
      respond_to do |format|
        format.html {
          redirect_to @document.absolute_url
        }
        format.json {
          render :json => {:properties => @document.to_json({:current_user => current_user}) }
        }
      end
    else
      render(:file => File.join(Rails.root, 'public/403.html'), :status => :forbidden, :layout => false)
    end

  end

  def show_properties
    @document = current_customer.groupdocuments.find(params[:id]).applicable_version_or_last_available
    if DocumentPolicy.viewable?(current_user, @document)
      respond_to do |format|
        format.html {
          redirect_to show_properties_document_path(@document)
        }
      end
    else
      flash_x_error I18n.t('controllers.groupdocuments.errors.document_access')
      redirect_to documents_path
    end
  end

  def properties
    @document = current_customer.groupdocuments.find(params[:id]).last_available
    respond_to do |format|
      format.json { render :json => {:properties => @document.to_json({:current_user => current_user}) }  }
      format.html { }
    end
  end

  def draw
    @document = current_customer.groupdocuments.find(params[:id]).last_available
    redirect_to show_properties_document_path(@document)
  end

  def destroy
    @document = current_customer.groupdocuments.find(params[:id]).last_available
    authorize @document, :destroy_groupdocument?
    events = @document.groupdocument.documents.to_a.sum { |d| d.events }.uniq
    if @document.groupdocument.destroy
      if events.any?
        events.each do |event|
          log_action(event, current_user, "update")
        end
      end
      flash[:success] = I18n.t('controllers.groupdocuments.successes.destroy')
      redirect_to documents_path
    else
      flash[:error] = I18n.t('controllers.groupdocuments.errors.destroy')
      redirect_to show_properties_document_path(@document)
    end
  end
end
# rubocop: enable all
