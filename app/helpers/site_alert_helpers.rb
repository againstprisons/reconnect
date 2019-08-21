module ReConnect::Helpers::SiteAlertHelpers
  def should_send_alert_email(type)
    return false unless ReConnect.app_config['site-alert-emails']['email']
    return true if ReConnect.app_config['site-alert-emails']['alerts'].include?('*')
    ReConnect.app_config['site-alert-emails']['alerts'].include?(type.to_s)
  end
end
