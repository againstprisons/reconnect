Sequel.migration do
  up do
    alter_table :penpal_relationships do
      add_column :confirmed, TrueClass, default: false
    end

    from(:penpal_relationships).update(confirmed: true)
  end

  down do
    alter_table :penpal_relationships do
      drop_column :confirmed
    end
  end
end
