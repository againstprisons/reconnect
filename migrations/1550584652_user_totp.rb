Sequel.migration do
  change do
    alter_table :users do
      add_column :totp_enabled, TrueClass
      add_column :totp_secret, String
    end
  end
end
