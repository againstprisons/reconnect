module ReConnect::Helpers::ApplicationHelpers
  require_relative './language_helpers'
  include ReConnect::Helpers::LanguageHelpers

  require_relative './maintenance_helpers'
  include ReConnect::Helpers::MaintenanceHelpers

  require_relative './csrf_helpers'
  include ReConnect::Helpers::CsrfHelpers

  require_relative './time_helpers'
  include ReConnect::Helpers::TimeHelpers

  require_relative './theme_helpers'
  include ReConnect::Helpers::ThemeHelpers

  require_relative './flash_helpers'
  include ReConnect::Helpers::FlashHelpers

  require_relative './user_helpers'
  include ReConnect::Helpers::UserHelpers

  require_relative './signup_helpers'
  include ReConnect::Helpers::SignupHelpers

  require_relative './navbar_helpers'
  include ReConnect::Helpers::NavbarHelpers

  require_relative './site_alert_helpers'
  include ReConnect::Helpers::SiteAlertHelpers

  def site_name
    ReConnect.app_config["site-name"]
  end

  def org_name
    ReConnect.app_config["org-name"]
  end

  def current_prefix?(path = '/')
    request.path.start_with?(path) ? 'current' : nil
  end

  def current?(path = '/')
    request.path == path ? 'current' : nil
  end
end
