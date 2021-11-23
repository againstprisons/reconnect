Sequel.migration do
  change do
    create_table :holiday_card_covers do
      primary_key :id
      TrueClass :enabled, null: false, default: true

      String :file_id, null: false
      String :preview_url, null: true

      String :credit, null: true

      foreign_key :creator, :users, null: false
      DateTime :created, null: false, default: Sequel.function(:NOW)
    end
  end
end
