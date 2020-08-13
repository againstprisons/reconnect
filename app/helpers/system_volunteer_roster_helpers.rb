module ReConnect::Helpers::SystemVolunteerRosterHelpers
  def roster_month(start)
    now = DateTime.now.to_date

    ts_start = DateTime.civil(start.year, start.month, 1, 0, 0, 0)
    ts_end = ts_start + 32
    ts_end = DateTime.civil(ts_end.year, ts_end.month, 1, 0, 0, 0)

    entries = (ts_start.to_date() .. ts_end.to_date()).to_a.map do |day|
      vre = ReConnect::Models::VolunteerRosterEntry.where(roster_day: day).first

      {
        :day => day,
        :day_friendly => day.strftime("%A, %-d %B %Y"),
        :roster_entry => vre,
        :past => day < now,
      }
    end

    {
      :ts_start => ts_start.to_date(),
      :ts_end => ts_end.to_date(),
      :entries => entries,
    }
  end

  def roster_available_volunteers
    ReConnect.app_config['volunteer-group-ids'].map do |gid|
      ReConnect::Models::Group[gid.to_i]&.user_groups&.map(&:user)&.map(&:id)
    end.flatten.compact.uniq.map do |uid|
      ReConnect::Models::User[uid]
    end.compact
  end
end