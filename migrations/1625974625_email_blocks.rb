Sequel.migration do
  change do
    create_table :email_blocks do
      primary_key :id

      TrueClass :is_domain, null: false, default: false
      String :email, null: false
      String :reason, null: true

      DateTime :created, null: false, default: Sequel.function(:NOW)
      foreign_key :creator, :users, null: true
    end
  end
end
