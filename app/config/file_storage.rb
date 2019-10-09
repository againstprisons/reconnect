module ReConnect::Config::FileStorage
  module_function

  def order
    0
  end

  def accept?(key, _type)
    key == "file-storage-dir"
  end

  def parse(value)
    if value.nil? || value.strip.empty?
      return {
        :warning => "Invalid value #{value.inspect}",
        :data => nil,
      }
    end

    return {:data => value}
  end

  def set(data)
    unless Dir.exist(data)
      Dir.mkdir(data)
    end
  end
end
