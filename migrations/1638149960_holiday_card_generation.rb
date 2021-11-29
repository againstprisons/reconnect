Sequel.migration do
  up do
    alter_table :correspondence do
      add_column :card_status, String, null: true
      add_column :card_file_id, String, null: true
    end

    from(:correspondence)
      .exclude(card_instance: nil)
      .update(card_status: 'ready')
  end

  down do
    alter_table :correspondence do
      drop_column :card_status
      drop_column :card_file_id
    end
  end
end
