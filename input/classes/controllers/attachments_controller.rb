# frozen_string_literal: true

class AttachmentsController < ApplicationController
  before_action :check_object, only: %i[new download create confirm_destroy destroy]

  def new
    @remaining = @scope_object.class::ATTACHMENTS_LIMIT - @scope_object.attachments.count
    logger.info("remaining = #{@remaining}")
    respond_to do |format|
      format.js
    end
  end

  # TODO: Simplify into smaller private methods
  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  def create
    authorize @scope_object, :add_attachment?
    @errors = []

    ActiveRecord::Base.transaction do
      @attachments = @scope_object.attachments.new(
        params[@scope_object.class.to_s.downcase][:attachments].map do |f|
          { title: f.original_filename, file: f }
        end
      )

      @attachments.each do |attachment|
        unless attachment.save
          @errors = attachment.errors
          raise ActiveRecord::Rollback
        end
      end
    end

    if @errors.blank?
      flash_x_success I18n.t("attachments.create.success")
    elsif @errors.messages.blank?
      flash_x_error I18n.t("attachments.create.error").to_s
    else
      flash_x_error "#{I18n.t('attachments.create.error')} : #{@errors.full_messages.join}"
    end

    # reload to refresh the object state after calling the ActiveRecord::Rollback
    @scope_object.reload
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

  def download
    authorize @scope_object, :download_attachment?
    attachment = @scope_object.attachments.find(params[:id])
    send_file(attachment.file.path, x_sendfile: true)
  end

  def confirm_destroy
    authorize @scope_object, :destroy_attachment?
    @attachment = @scope_object.attachments.find(params[:id])
  end

  def destroy
    authorize @scope_object, :destroy_attachment?
    attachment = @scope_object.attachments.find(params[:id])
    if attachment.destroy
      flash_x_success I18n.t("attachments.destroy.success")
    else
      flash_x_error I18n.t("attachments.destroy.error")
    end
  end

  private

  def check_object
    raise "method_not_allowed" unless roles_or_users?

    @scope_object = current_customer.send(matches.first[1].pluralize).find(params[matches.first[0]])
  end

  def matches
    params.keys.map { |k| k.match(/(.*)_id$/) }.compact
  end

  def roles_or_users?
    !matches.first[1].nil? &&
      %w[roles users].include?(matches.first[1].pluralize) &&
      params[matches.first[0]].to_i.positive?
  end
end
