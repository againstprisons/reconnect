module ReConnect::Helpers::HolidayCardHelpers
  def holidaycard_penpal_list(instance, opts = {})
    opts[:n] = 5 unless opts.key?(:n)
    opts[:count_field] = :online_count unless opts.key?(:count_field)
    opts[:count_max] = 3 unless opts.key?(:count_max)

    current_count, counts = 0, []
    while counts.length < opts[:n] && current_count <= opts[:count_max]
      this_count = ReConnect::Models::HolidayCardCount
        .where({ :card_instance => instance, opts[:count_field] => current_count })
        .order(Sequel.lit('RANDOM()'))
        .limit(opts[:n])
        .all

      this_count = this_count.map do |c|
        next nil if c[opts[:count_field]] >= opts[:count_max]
        penpal = ReConnect::Models::Penpal[c.penpal_id]
        next nil if penpal.decrypt(:prisoner_number).start_with?("test")

        {
          cobj: c,
          penpal: penpal
        }
      end.compact

      current_count += 1
      counts << this_count
      counts.flatten!
    end

    counts.shuffle
  end
end
