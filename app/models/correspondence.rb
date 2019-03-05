class ReConnect::Models::Correspondence < Sequel::Model(:correspondence)
  def self.find_for_relationship(relationship)
    [
      self.where(:sending_penpal => relationship.penpal_one, :receiving_penpal => relationship.penpal_two).all,
      self.where(:sending_penpal => relationship.penpal_two, :receiving_penpal => relationship.penpal_one).all,
    ].flatten.compact.sort{|a, b| b.creation <=> a.creation}
  end

  def get_data(current_penpal = nil)
    current_penpal = current_penpal.id if current_penpal.respond_to?(:id)

    penpal_sending = ReConnect::Models::Penpal[self.sending_penpal]
    penpal_receiving = ReConnect::Models::Penpal[self.receiving_penpal]

    actioned = !(self.actioning_user.nil?)
    actioning_user = ReConnect::Models::User[self.actioning_user]
    actioning_user_name = actioned ? actioning_user.decrypt(:name) : nil

    {
      :id => self.id,
      :creation => self.creation,

      :sending_penpal => penpal_sending,
      :sending_penpal_name => penpal_sending.get_name,
      :receiving_penpal => penpal_receiving,
      :receiving_penpal_name => penpal_receiving.get_name,
      :receiving_is_incarcerated => penpal_receiving.is_incarcerated,

      :this_user_sent => penpal_sending.id == current_penpal,

      :actioned => actioned,
      :actioning_user => actioning_user,
      :actioning_user_name => actioning_user_name,
    }
  end

  def delete!
    ReConnect::Models::File.where(:file_id => self.file_id).first&.delete!
    self.delete
  end
end
