Sequel.migration do
  change do
    alter_table :users do
      add_foreign_key :penpal_id, :penpals, null: true
    end

    create_table :penpals do
      primary_key :id

      foreign_key :user_id, :users, null: true
      TrueClass :is_incarcerated, null: false, default: false

      # Following are only used if is_incarcerated is true
      String :address, null: true
      String :prisoner_number, null: true
      String :name, null: true
    end

    create_table :penpal_relationships do
      primary_key :id

      foreign_key :penpal_one, :penpals
      foreign_key :penpal_two, :penpals
    end
  end
end
