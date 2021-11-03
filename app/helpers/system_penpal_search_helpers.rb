require 'shellwords'

module ReConnect::Helpers::SystemPenpalSearchHelpers
  def penpal_search_perform(query, opts = {})
    penpal_ids = []

    query_parts = Shellwords.split(query)
    query_parts.each do |part|
      part_type, part_param = part.split(':', 2)

      # Match on search part type
      case part_type.downcase
      when 'prison'
        prison = ReConnect::Models::Prison[part_param.to_i]
        throw "Prison does not exist: #{part_param.inspect}" unless prison

        # Get IDs of all penpals in this prison
        penpal_ids << ReConnect::Models::PenpalFilter
          .perform_filter("prison", prison.id.to_s)
          .all
          .map(&:penpal_id)

      else
        throw "Unknown search type: #{part_type.inspect}"
      end
    end

    # Return flattened list
    penpal_ids.flatten.uniq
  end
end
