Sequel.migration do
  change do
    alter_table :users do
      add_column :preferred_language, String
    end
  end
end
