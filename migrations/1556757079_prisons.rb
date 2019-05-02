Sequel.migration do
  change do
    create_table :prisons do
      primary_key :id

      String :name
      String :physical_address
      String :email_address
    end
  end
end
