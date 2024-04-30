# frozen_string_literal: true

# Base mailer class for all mailer classes used within this application
class ApplicationMailer < ActionMailer::Base
  default from: Settings.support_email
  layout "mail"

  # Collection of logo image paths for various social media platforms
  # @type [Hash{Symbol => String}]
  # @todo Centralize these in some shared model class as they already exist in
  #       various forms elsewhere (e.g.: {CustomerSettingHelper},
  #       {DeviseCustomMailer}, {PasswordsController}, `mail.html.erb`, etc.)
  SOCIAL_MEDIA_LOGOS = {
    googleplus: "app/assets/images/mails/googleplus.gif",
    linkedin: "app/assets/images/mails/linkedin.gif",
    twitter: "app/assets/images/mails/twitter.gif",
    viadeo: "app/assets/images/mails/viadeo.gif",
    youtube: "app/assets/images/mails/youtube.gif"
  }.freeze
end
