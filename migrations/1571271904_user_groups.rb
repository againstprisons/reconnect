Sequel.migration do
  change do
    create_table :groups do
      primary_key :id

      String :name
      TrueClass :requires_2fa, null: false, default: false
      DateTime :created, null: false, default: Sequel.function(:NOW)
    end

    create_table :user_groups do
      primary_key :id

      foreign_key :user_id, :users, null: false
      foreign_key :group_id, :groups, null: false
      DateTime :created, null: false, default: Sequel.function(:NOW)
    end

    create_table :group_roles do
      primary_key :id

      foreign_key :group_id, :groups, null: false
      String :role, null: false
    end
  end
end
