Sequel.migration do
  change do
    alter_table :users do
      add_column :tos_agreed, DateTime, null: true, default: nil
    end
  end
end
