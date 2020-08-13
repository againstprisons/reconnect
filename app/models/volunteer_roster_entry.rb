class ReConnect::Models::VolunteerRosterEntry < Sequel::Model(:volunteer_roster_entry)
  many_to_one :user

  def get_user_name
    if self.user_id.nil?
      return self.user_name
    end

    self.user.get_name.join(' ')
  end
end
