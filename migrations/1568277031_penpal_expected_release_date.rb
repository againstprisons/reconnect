Sequel.migration do
  change do
    alter_table :penpals do
      add_column :expected_release_date, String
    end
  end
end
