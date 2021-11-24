module ReConnect::Config::CorrespondenceCardInstances
  module_function

  def order
    100
  end

  def accept?(key, _type)
    key == "correspondence-card-instances"
  end

  def parse(value)
    begin
      value = JSON.parse(value)
    rescue => e
      return {
        :warning => "Failed to parse JSON: #{e.class.name}: #{e}",
        :data => {},
      }
    end

    warnings = {}
    instances = value.map do |k, v|
      warnings[k] ||= []

      # Check for required keys
      %w[enabled friendly penpal_id statuses].each do |key|
        unless v.key?(key)
          warnings[k] << "missing key #{key.inspect}"
        end
      end

      # Set defaults
      v["show_on_index"] = false unless v.key?("show_on_index")

      [k, v]
    end.compact.to_h

    warnings = warnings.map do |k, v|
      next nil if v&.empty?
      "#{k}: #{v&.join(", ")}"
    end.compact.join("; ")
    warnings = nil if warnings.empty?

    {
      :data => instances,
      :warning => warnings,
    }
  end
end
