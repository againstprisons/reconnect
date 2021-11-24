Sequel.migration do
  change do
    alter_table :correspondence do
      add_foreign_key :card_cover, :holiday_card_covers, null: true
    end
  end
end
