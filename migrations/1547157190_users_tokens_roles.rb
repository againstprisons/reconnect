Sequel.migration do
  change do
    create_table :users do
      primary_key :id

      String :email, null: false
      String :password_hash
      String :name

      String :disabled_reason
    end

    create_table :user_roles do
      primary_key :id
      foreign_key :user_id, :users

      String :role, null: false
    end

    create_table :tokens do
      primary_key :id
      foreign_key :user_id, :users, null: true

      String :token, null: false
      String :use, null: false
      TrueClass :valid, null: false

      String :extra_data
    end
  end
end
