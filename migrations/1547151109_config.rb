Sequel.migration do
  change do
    create_table :config do
      primary_key :id

      String :key
      String :value
      String :type
    end
  end
end
