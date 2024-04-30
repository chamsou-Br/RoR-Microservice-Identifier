# frozen_string_literal: true

module AttachmentsHelper
  def show_import_button?(entity)
    policy(entity).add_attachment? && entity.attachments.size < entity.class.name.constantize::ATTACHMENTS_LIMIT
  end
end
