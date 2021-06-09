Sequel.migration do
  change do
    create_table :ip_blocks do
      primary_key :id

      String :ip_address, null: false
      String :reason, null: true

      DateTime :created, null: false, default: Sequel.function(:NOW)
      foreign_key :creator, :users, null: true
    end
  end
end
