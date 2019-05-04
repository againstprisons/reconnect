Sequel.migration do
  change do
    alter_table :penpal_relationships do
      add_column :email_approved, TrueClass, default: false
      add_foreign_key :email_approved_by_id, :users, null: true
    end

    alter_table :correspondence do
      add_column :sent, String, default: "no"
    end
  end
end
