Sequel.migration do
  change do
    alter_table :email_queue do
      add_column :recipient_assoc, String, null: true
      add_column :recipient_assoc_data, String, null: true
    end
  end
end
