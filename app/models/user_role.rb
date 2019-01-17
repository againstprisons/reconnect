class ReConnect::Models::UserRole < Sequel::Model
  many_to_one :user
end
