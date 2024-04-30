# frozen_string_literal: true

class PasswordsController < Devise::PasswordsController
  def create
    attributes = resource_params
    attributes[:customer_id] = current_customer.id

    logger.debug "password recovery for #{attributes[:customer_id]} #{attributes[:email]}"
    self.resource = resource_class.send_reset_password_instructions(attributes)
    yield resource if block_given?

    if successfully_sent?(resource)
      respond_with({}, location: after_sending_reset_password_instructions_path_for(resource_name))
    else
      respond_with(resource)
    end
  end

  private

  def add_inline_attachment!
    image_names = ["keyboard-pyx4.png", "logo.gif", "linkedin.gif",
                   "viadeo.gif", "twitter.gif", "googleplus.gif", "youtube.gif"]

    image_names.each do |image_name|
      attachments.inline[image_name] = load_image(image_name)
    end
  end

  def load_image(file_name)
    File.read(File.join(Rails.root, "app", "assets", "images", "mails", file_name))
  end
end
