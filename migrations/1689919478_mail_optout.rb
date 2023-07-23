Sequel.migration do
  change do
    alter_table :penpals do
      add_column :mail_optouts, String, null: true
    end
  end
end
