module ReConnect::Helpers::SignupHelpers
  def signups_enabled?
    ReConnect.app_config["signups"]
  end
end
