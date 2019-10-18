class ReConnect::Models::GroupRole < Sequel::Model(:group_roles)
  many_to_one :group
end

