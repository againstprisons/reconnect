Sequel.migration do
  up do
    alter_table :penpals do
      add_column :status_override, TrueClass, null: false, default: false
    end
  end

  down do
    alter_table :penpals do
      drop_column :status_override
    end
  end
end
