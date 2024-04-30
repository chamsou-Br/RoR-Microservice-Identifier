# frozen_string_literal: true

module Store::PackagesHelper
  def humanize_package_state(state)
    I18n.t(state, scope: "helpers.package.humanize_package_state")
  end
end
