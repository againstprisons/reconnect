class ReConnect::Models::Correspondence < Sequel::Model(:correspondence)
  def self.find_for_relationship(relationship)
    [
      self.where(:sending_penpal => relationship.penpal_one, :receiving_penpal => relationship.penpal_two).all,
      self.where(:sending_penpal => relationship.penpal_two, :receiving_penpal => relationship.penpal_one).all,
    ].flatten.compact.sort{|a, b| b.creation <=> a.creation}
  end

  def delete!
    ReConnect::Models::File.where(:file_id => self.file_id).first&.delete!
    self.delete
  end
end
