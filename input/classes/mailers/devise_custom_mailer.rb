# frozen_string_literal: true

# TODO: Replace `opts` overwrites in each public method to avoid shadowing the
# local variables, perhaps with explicit `super()` calls
class DeviseCustomMailer < Devise::Mailer
  default template_path: "mail"

  SOCIAL_MEDIA_GIFS = %w[linkedin viadeo twitter googleplus youtube].freeze

  def confirmation_instructions(record, token, opts = {})
    add_inline_attachment!(record.customer)
    @title = "[#{record.customer.nickname}] " + I18n.t("devise.mailer.confirmation_instructions.subject")
    # rubocop:disable Lint/ShadowedArgument
    opts = {
      subject: @title
    }
    # rubocop:enable Lint/ShadowedArgument
    @greetings_message = I18n.t("devise.mailer.confirmation_instructions.greetings_goodbye")
    super
  end

  def reset_password_instructions(record, token, opts = {})
    add_inline_attachment!(record.customer)
    @title = I18n.t("devise.mailer.reset_password_instructions.title", instance_name: record.customer.nickname)
    subject = "[#{record.customer.nickname}] " + I18n.t("devise.mailer.reset_password_instructions.subject")
    # rubocop:disable Lint/ShadowedArgument
    opts = {
      subject: subject
    }
    # rubocop:enable Lint/ShadowedArgument
    @greetings_message = I18n.t("devise.mailer.reset_password_instructions.greetings_goodbye")
    super
  end

  def unlock_instructions(record, token, opts = {})
    add_inline_attachment!(record.customer)
    @title = "[#{record.customer.nickname}] " + I18n.t("devise.mailer.unlock_instructions.subject")
    # rubocop:disable Lint/ShadowedArgument
    opts = {
      subject: @title
    }
    # rubocop:enable Lint/ShadowedArgument
    super
  end

  def invitation_instructions(record, token, opts = {})
    add_inline_attachment!(record.customer)
    @title = I18n.t("devise.mailer.invitation_instructions.title", instance_name: record.customer.nickname)
    subject = "[#{record.customer.nickname}] " + I18n.t("devise.mailer.invitation_instructions.subject")
    # rubocop:disable Lint/ShadowedArgument
    opts = {
      subject: subject
    }
    # rubocop:enable Lint/ShadowedArgument
    @greetings_message = I18n.t("devise.mailer.invitation_instructions.greetings_goodbye")
    super
  end

  private

  def add_inline_attachment!(customer = nil)
    attachments.inline["logo.gif"] =
      begin
        if customer_logo_for_mail?(customer)
          File.read(Rails.root.join("public/#{customer.settings.logo.url}"))
        else
          mail_image("logo.gif")
        end
      rescue StandardError
        nil
      end

    # Attaches GIFs for each of the filenames provided
    SOCIAL_MEDIA_GIFS.each do |filename|
      attachments.inline["#{filename}.gif"] = mail_image("#{filename}.gif")
    end
  end

  # Reads a file with the given `filename` under app/assets/images/mails
  def mail_image(filename)
    File.read(File.join(Rails.root, "app", "assets", "images", "mails", filename))
  end

  # Does the customer exist and have a logo intended for application mails?
  def customer_logo_for_mail?(customer)
    customer.present? && customer.settings.logo.present? && customer.settings.logo_usage == "application_print_mail"
  end
end
