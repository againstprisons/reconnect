Sequel.migration do
  change do
    alter_table :penpals do
      add_column :middle_name, String, null: true
    end
  end
end
