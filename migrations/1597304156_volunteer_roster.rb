Sequel.migration do
  change do
    create_table :volunteer_roster_entry do
      primary_key :id

      foreign_key :user_id, :users, null: true
      String :user_name, null: true
      Date :roster_day, null: false
      TrueClass :is_admin_override, null: false, default: false

      DateTime :created, null: false, default: Sequel.function(:NOW)
    end
  end
end
