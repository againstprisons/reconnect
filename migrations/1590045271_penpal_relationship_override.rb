Sequel.migration do
    up do
      alter_table :penpal_relationships do
        add_column :status_override, TrueClass, null: false, default: false
      end
    end
  
    down do
      alter_table :penpal_relationships do
        drop_column :status_override
      end
    end
  end
  