Sequel.migration do
  change do
    alter_table :penpals do
      add_column :notes, String
      add_column :intro, String
    end
  end
end
