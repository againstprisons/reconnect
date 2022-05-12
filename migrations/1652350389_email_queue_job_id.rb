Sequel.migration do
  change do
    alter_table :email_queue do
      add_column :send_job_id, String, null: true
    end
  end
end
