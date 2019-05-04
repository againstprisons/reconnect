Sequel.migration do
  change do
    alter_table :email_queue do
      add_column :annotate_subject, TrueClass, default: true
    end
  end
end
