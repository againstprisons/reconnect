Sequel.migration do
  change do
    alter_table :prisons do
      add_column :require_prn, TrueClass, null: false, default: false
    end
  end
end