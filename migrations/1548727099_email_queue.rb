Sequel.migration do
  change do
    create_table :email_queue do
      primary_key :id

      DateTime :creation
      String :recipients
      String :subject

      String :content_text
      String :content_html
      String :attachments

      String :queue_status
    end
  end
end
