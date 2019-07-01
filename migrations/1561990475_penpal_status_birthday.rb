Sequel.migration do
  change do
    alter_table :penpals do
      add_column :birthday, String, null: true
      add_column :status, String, null: true
    end
  end
end
