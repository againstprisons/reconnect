Sequel.migration do
  change do
    alter_table :users do
      add_column :disable_sending_to_waiting, TrueClass, default: false
    end
  end
end
