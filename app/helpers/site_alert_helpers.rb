module ReConnect::Helpers::SiteAlertHelpers
  def should_send_alert_email(type)
    return false unless ReConnect.app_config['site-alert-emails']['email']
    return true if ReConnect.app_config['site-alert-emails']['alerts'].include?('*')
    ReConnect.app_config['site-alert-emails']['alerts'].include?(type.to_s)
  end

  def make_generic_alert_email(type, message, extra_data = {})
    return nil unless should_send_alert_email(type)

    data = {
      alert_type: type,
      alert_message: message,
      alert_data: extra_data,
    }

    email = ReConnect::Models::EmailQueue.new_from_template("alert_generic", data)
    email.queue_status = "queued"
    email.encrypt(:subject, "Site alert: #{type}")
    email.encrypt(:recipients, JSON.dump({
      mode: 'list',
      list: [ReConnect.app_config['site-alert-emails']['email']]
    }))

    email.save
    email
  end
end
