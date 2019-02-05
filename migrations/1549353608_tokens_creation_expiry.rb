Sequel.migration do
  up do
    add_column :tokens, :creation, DateTime, null: true
    add_column :tokens, :expiry, DateTime, null: true

    from(:tokens).update(creation: Time.now)
  end

  down do
    drop_column :tokens, :creation
    drop_column :tokens, :expiry
  end
end
