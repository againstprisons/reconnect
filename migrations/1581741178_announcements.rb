Sequel.migration do
  change do
    create_table :announcements do
      primary_key :id

      String :message, null: false
      TrueClass :only_logged_in, null: false, default: false
      TrueClass :valid, null: false, default: true
      DateTime :created, null: false, default: Sequel.function(:NOW)
    end
  end
end
