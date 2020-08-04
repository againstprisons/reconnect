module ReConnect::Config::VolunteerGroupIDs
  module_function

  def order
    100
  end

  def accept?(key, _type)
    key == "volunteer-group-ids"
  end

  def default
    []
  end

  def parse(value)
    begin
      value = JSON.parse(value)
    rescue => e
      return {
        :warning => "Failed to parse JSON: #{e.class.name}: #{e}",
        :data => [],
      }
    end

    groups = value.map do |gid|
      ReConnect::Models::Group[gid]&.id
    end.compact

    if groups.length != value.length
      filtered = value.reject { |gid| groups.include?(gid) }

      return {
        :warning => "The following groups do not exist and have been filtered out: #{filtered.inspect}",
        :data => groups,
      }
    end

    {:data => groups}
  end
end
