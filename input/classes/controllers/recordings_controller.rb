# frozen_string_literal: true

class RecordingsController < ApplicationController
  def index
    @recordings = current_customer.recordings
  end

  def show
    @recording = current_customer.recordings.find(params[:id])
    respond_to do |format|
      format.json { render json: { properties: @recording.to_json } }
      # TODO: CRUD recordings
      format.html { redirect_to root_path }
    end
  end

  def linkable
    return unless request.xhr?

    recordings = current_customer.recordings
    respond_to do |format|
      format.json { render json: { recordings: recordings.to_json } }
    end
  end
end
