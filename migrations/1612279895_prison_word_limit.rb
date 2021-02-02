Sequel.migration do
  change do
    alter_table :prisons do
      add_column :word_limit, Integer, null: true, default: nil
    end
  end
end