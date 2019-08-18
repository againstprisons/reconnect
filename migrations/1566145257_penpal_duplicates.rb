Sequel.migration do
  change do
    create_table :penpal_duplicates do
      primary_key :id

      String :prisoner_number_idx
      String :prisoner_number
      String :duplicate_ids
    end
  end
end
