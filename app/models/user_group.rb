class ReConnect::Models::UserGroup < Sequel::Model(:user_groups)
  many_to_one :user
  many_to_one :group
end
