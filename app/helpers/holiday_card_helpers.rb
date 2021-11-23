module ReConnect::Helpers::HolidayCardHelpers
  def holidaycard_penpal_list(instance, opts = {})
    opts[:n] ||= 5
    opts[:count_field] ||= :online_count
    opts[:count_max] ||= 3

    current_count, counts = 0, []
    while counts.length < opts[:n] && current_count < opts[:count_max]
      counts << ReConnect::Models::HolidayCardCount
        .where({ :card_instance => instance, opts[:count_field] => current_count })
        .order(Sequel.lit('RANDOM()'))
        .limit(opts[:n])
        .all

      current_count += 1
      counts.flatten!
    end

    # Get the penpal objects
    counts.map do |cobj|
      {
        cobj: cobj,
        penpal: ReConnect::Models::Penpal[cobj.penpal_id],
      }
    end.shuffle
  end
end
