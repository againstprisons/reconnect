Sequel.migration do
  change do
    alter_table :penpals do
      add_column :is_advocacy, TrueClass
      add_column :correspondence_guide_sent, TrueClass
    end
  end
end
