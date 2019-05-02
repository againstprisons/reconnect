Sequel.migration do
  change do
    alter_table :penpals do
      add_column :prison_id, String
    end
  end
end
