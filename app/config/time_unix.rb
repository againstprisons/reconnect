module ReConnect::Config::TimeUnix
  module_function

  def order
    -10000
  end

  def accept?(key, type)
    type == :time_unix
  end

  def parse(value)
    begin
      { data: Time.at(value.to_i), }
    rescue => e
      {
        warning: "Failed to parse UNIX timestamp: #{e.class.name}: #{e}",
        data: nil,
      }
    end
  end
end
