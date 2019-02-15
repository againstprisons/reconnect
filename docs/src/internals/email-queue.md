# Email queueing and templates

Emails are sent by a scheduled Sidekiq job, pulling the email data from the
database. Emails are handled by the `ReConnect::Models::EmailQueue` model.

Emails can be sent with both text and HTML parts, and can have arbitrary
attachments.

## Queueing a new email

To queue a new email with custom content, first create an `EmailQueue` instance,
save it using `instance.save()` (to generate an ID), and then add the data
by encrypting it on the model using the `instance.encrypt(field, data)` method.

The `content_text` and `content_html` encrypted fields store the contents of
the text and HTML parts, respectively.

The `subject` encrypted field stores the email subject line.

The email queue sender only sends emails that have their `queue_status` set to
`"queued"`. The `queue_status` field is **not** encrypted.

### Recipients list

The recipients list can be either a list of email addresses to send to, or a
list of roles (to send the email to everyone who has those roles). The
recipients list is stored as JSON in the `recipients` encrypted field of the
model.

To send to a list of email addresses, the following JSON would be used:

```json
{
  "mode": "list",
  "list": [
    "user_one@example.com",
    "user_two@example.com"
  ]
}
```

To send to all users with the given roles, the following JSON would be used:

```json
{
  "mode": "roles",
  "roles": [
    "system:alert_emails"
  ]
}
```

### Attachments

The attachments to the email are stored an JSON in the `attachments` encrypted
field of the model. The JSON is in the format of an array of hashes, with
`"filename"` and `"content"` keys. Multiple attachments are allowed.

An example:

```json
[
  {
    "filename": "test.txt",
    "content": "This is a test text file!"
  }
]
```

## Email templates

To send an email using a template, you can call the `new_from_template` method
on the `EmailQueue` class, passing in the name of the template to use, and
a hash of data to pass to the template.

After doing this, you must manually set the queue status, set a subject line, 
and add a list of recipients.

An example:

```ruby
email = ReConnect::Models::EmailQueue.new_from_template("password_reset", data)
email.queue_status = "queued"
email.encrypt(:subject, "Password reset")
email.encrypt(:recipients, recipients_list)
email.save
```

### Previewing an email template

You can preview any email template by visiting the
`/system/debugging/emailpreview/:lang/:template.:type` page, where `:lang` is
the template language, `:template` is the template name, and `:type` is the
template type (either `html` or `txt`).

You can pass in a `data` query parameter, containing JSON data, which is passed
to the template.

For example, for the HTML version of the password reset template, you could
visit `/system/debugging/emailpreview/en/password_reset.html`.
