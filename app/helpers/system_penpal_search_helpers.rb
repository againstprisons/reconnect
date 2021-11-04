require 'shellwords'

module ReConnect::Helpers::SystemPenpalSearchHelpers
  def penpal_search_perform(query, opts = {})
    penpal_ids = []
    search_opts = opts[:search_opts] || {}
    search_opts[:mode] ||= :any

    query_parts = Shellwords.split(query)
    query_parts.each do |part|
      # Handle mode switching
      if part == 'all'
        search_opts[:mode] = :all
        next
      end

      part_type, part_param = part.split(':', 2)

      # Match on search part type
      case part_type.downcase
      when 'prison'
        prison = ReConnect::Models::Prison[part_param.to_i]
        raise "Prison does not exist: #{part_param.inspect}" unless prison

        # Get IDs of all penpals in this prison
        penpal_ids << ReConnect::Models::PenpalFilter
          .perform_filter("prison", prison.id.to_s)
          .all
          .map(&:penpal_id)

      when 'status'
        # Check status exists
        unless ReConnect.app_config['penpal-statuses'].include?(part_param)
          raise "Status does not exist: #{part_param.inspect}"
        end

        # Get IDs of all penpals with this status
        penpal_ids << ReConnect::Models::PenpalFilter
          .perform_filter("status", part_param)
          .all
          .map(&:penpal_id)

      else
        raise "Unknown search type: #{part_type.inspect}"
      end
    end

    case search_opts[:mode]
    when :all
      # Return list of IDs that match all
      penpal_ids.reduce(:&).uniq

    else
      # Return flattened list
      penpal_ids.flatten.uniq
    end
  end
end
