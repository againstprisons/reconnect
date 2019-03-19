Sequel.migration do
  change do
    create_table :penpal_filters do
      primary_key :id
      foreign_key :penpal_id, :penpals

      String :filter_label
      String :filter_value
    end
  end
end
