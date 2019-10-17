class ReConnect::Models::Group < Sequel::Model
  one_to_many :user_groups
  one_to_many :group_roles
end
