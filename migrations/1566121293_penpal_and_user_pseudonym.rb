Sequel.migration do
  change do
    alter_table :penpals do
      add_column :pseudonym, String, null: true
    end

    alter_table :users do
      add_column :pseudonym, String, null: true
    end
  end
end
