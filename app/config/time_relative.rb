require "chronic"

module ReConnect::Config::TimeRelative
  module_function

  def order
    -10000
  end

  def accept?(key, type)
    type == :time_relative
  end

  def parse(value)
    begin
      loaded = Chronic.parse(value, :guess => true)
      throw "nil" unless loaded
      { data: loaded, }
    rescue => e
      {
        warning: "Failed to parse relative time",
        data: nil,
      }
    end
  end
end
