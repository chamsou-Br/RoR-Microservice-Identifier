# frozen_string_literal: true

class PartialsController < ApplicationController
  def show
    @partial = get_partial(params[:id].to_sym)
    raise ActiveRecord::RecordNotFound if @partial.nil?

    respond_to do |format|
      format.js {}
      format.html { render partial: @partial }
    end
  end

  private

  def get_partial(id)
    {
      mdmove: "layouts/classmentmodal_headless",
      notificationheader: "notifications/header_button_headless",
      headernotification: "header/notification",
      headernotificationcount: "header/notification_count"
    }[id]
  end
end
