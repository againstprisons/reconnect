module ReConnect::Config::SignupAgeGate
  module_function

  def order
    100
  end

  def accept?(key, _type)
    key == "signup-age-gate"
  end

  def default
    "18 years ago"
  end

  def parse(value)
    loaded = Chronic.parse(value, :guess => true)
    if loaded.nil?
      return {
        :warning => "Failed to parse time period",
        :data => self.default,
      }
    end

    {:data => value}
  end
end
