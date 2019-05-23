Sequel.migration do
  change do
    alter_table :penpal_relationships do
      add_column :notes, String, null: true
    end
  end
end
