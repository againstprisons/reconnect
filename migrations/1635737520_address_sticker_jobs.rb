Sequel.migration do
  change do
    create_table :address_sticker_jobs do
      primary_key :id
      foreign_key :user_id, :users, null: false

      String :status, null: false, default: 'pending'
      String :page_type, null: false, default: '__list__'

      String :source_file_id, null: false
      String :file_id, null: true

      TrueClass :deleted, null: false, default: false
      DateTime :created, null: false, default: Sequel.function(:NOW)
    end
  end
end
