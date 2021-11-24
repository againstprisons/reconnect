Sequel.migration do
  change do
    create_table :correspondence_card_count do
      primary_key :id

      foreign_key :penpal_id, :penpals, null: false
      String :card_instance, null: false
      Integer :online_count, null: false, default: 0
      Integer :manual_count, null: false, default: 0
    end

    alter_table :correspondence do
      add_column :card_instance, String, null: true
    end

    alter_table :penpal_relationships do
      add_column :card_instance, String, null: true
    end
  end
end
