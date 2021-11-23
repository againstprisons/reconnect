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
      instances = JSON.parse(value)
    rescue => e
      return {
        :warning => "Failed to parse JSON: #{e.class.name}: #{e}",
        :data => {},
      }
    end

    warnings = {}
    instances.each do |k, v|
      this_warnings = []
      %w[friendly penpal_id statuses].each do |key|
        unless v.key?(key)
          this_warnings << "missing key #{key.inspect}"
        end
      end
      warnings[k] = this_warnings unless this_warnings.empty?
    end

    {
      :data => instances,
      :warning => (warnings.map { |k, v| v.empty? ? nil : v }.compact.map { |k, v| "#{k}: #{v.join(', ')}" }.compact.join("; ") unless warnings.empty?),
    }
  end
end
