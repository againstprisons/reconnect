# XXX: This migration does not keep the name data, as it's not feasible to
# connect to keyderiv and decrypt/re-encrypt the name during the migrations.

Sequel.migration do
  up do
    alter_table :penpals do
      add_column :first_name, String, null: true
      add_column :last_name, String, null: true
      drop_column :name
    end

    alter_table :users do
      add_column :first_name, String, null: true
      add_column :last_name, String, null: true
      drop_column :name
    end
  end

  down do
    alter_table :penpals do
      add_column :name, String, null: true
      drop_column :first_name
      drop_column :last_name
    end

    alter_table :users do
      add_column :name, String, null: true
      drop_column :first_name
      drop_column :last_name
    end
  end
end
