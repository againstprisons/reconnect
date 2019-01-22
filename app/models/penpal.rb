class ReConnect::Models::Penpal < Sequel::Model
  one_to_one :user

  def self.new_for_user(user)
    user = user.id if user.respond_to?(:id)
    self.new(:user_id => user, :is_incarcerated => false)
  end

  def get_name
    return self.user.decrypt(:name) if self.user
    self.decrypt(:name)
  end

  def relationship_count
    ds_one = ReConnect::Models::PenpalRelationship.where(:penpal_one => self.id)
    ds_two = ReConnect::Models::PenpalRelationship.where(:penpal_two => self.id)

    ds_one.count + ds_two.count
  end

  def relationships
    ds_one = ReConnect::Models::PenpalRelationship.where(:penpal_one => self.id)
    ds_two = ReConnect::Models::PenpalRelationship.where(:penpal_two => self.id)

    [ds_one.all, ds_two.all].flatten.compact
  end
end
