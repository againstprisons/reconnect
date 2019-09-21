Sequel.migration do
  up do
    alter_table :penpals do
      add_column :creation, DateTime, null: true
    end

    from(:penpals).update(creation: Time.now)
  end

  down do
    alter_table :penpals do
      drop_column :creation
    end
  end
end
