module ReConnect::Helpers::HolidayCardHelpers
  def holidaycard_penpal_list(instance, opts = {})
    opts[:n] ||= 5
    opts[:count_field] ||= :online_count

    # Get smallest count in the database
    smallest = ReConnect::Models::HolidayCardCount
      .where(card_instance: instance)
      .order(Sequel.asc(opts[:count_field]))
      .first
      &.[](opts[:count_field])
    return [] unless smallest

    # Get up to `n` random entries with that count
    counts = ReConnect::Models::HolidayCardCount
      .where({ :card_instance => instance, opts[:count_field] => smallest })
      .order(Sequel.lit('RANDOM()'))
      .limit(opts[:n])
      .all

    # Get the penpal objects
    counts.map do |cobj|
      {
        cobj: cobj,
        penpal: ReConnect::Models::Penpal[cobj.penpal_id],
      }
    end
  end
end
