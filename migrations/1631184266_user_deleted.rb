Sequel.migration do
  change do
    alter_table :users do
      add_column :soft_deleted, TrueClass, null: false, default: false
      add_column :purge_at_next_opportunity, TrueClass, null: false, default: false
    end
  end
end
