module ReConnect::Helpers::SignupHelpers
  def signups_enabled?
    cfg = ReConnect::Models::Config.where(:key => 'signups').first
    return false unless cfg
    return cfg.value == 'yes'
  end
end
