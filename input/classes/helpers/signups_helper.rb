# frozen_string_literal: true

module SignupsHelper
  def language_data_url(struct)
    url = link_to new_signup_path(struct.locale)
    url.to_s
  end
end
