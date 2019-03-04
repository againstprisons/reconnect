Sequel.migration do
  change do
    create_table :correspondence do
      primary_key :id

      foreign_key :sending_penpal, :penpals
      foreign_key :receiving_penpal, :penpals

      foreign_key :creating_user, :users
      foreign_key :actioning_user, :users

      DateTime :creation
      String :file_id
    end
  end
end
