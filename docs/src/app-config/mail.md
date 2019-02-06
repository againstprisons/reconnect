# Mail preferences

Mail preferences can be changed through the web interface at
`/system/configuration/mail`.

## Email from address

The email address used in the "From" field of outgoing emails is stored in the
database as the `email-from` configuration key. 

## Subject line prefix

The prefix used for email subject lines is stored in the database as the
`email-subject-prefix` key. The available options are:

* `none`: No prefix (`Subject`)
* `org-name`: Organisation name, followed by a colon (`Organisation Name: Subject`)
* `org-name-brackets`: Organisation name, in brackets (`[Organisation Name] Subject`)
* `site-name`: Organisation name, followed by a colon (`Site Name: Subject`)
* `site-name-brackets`: Organisation name, in brackets (`[Site Name] Subject`)

## SMTP login details

The SMTP login details, as a URL, are stored in the database as the
`email-smtp-host` key.

The URL scheme is ignored, and when the web interface changes the URL, it does
not add a scheme.

The username, password, host, and port are specified in the standard URL format.
However, the username and password fields are both URL escaped. As an example,
to connect to the SMTP server at `localhost:1234` with a username of
`test@example.com` and a password of `P@55word`, the URL would look like the
following: `//test%40example.com:P%4055word@localhost:1234`.

Other options are controlled by query parameters on the URL. The available
options are:

* `starttls` - whether to enable StartTLS (`yes` to enable, any other value to
  disable; default: not set)
* `tls` - whether to enable TLS (`yes` to enable, any other value to disable;
  default: not set)
* `verify_mode` - OpenSSL verification mode (options: `NONE` for no
  verification, `PEER` for full peer verification; default: `PEER`)
* `authentication` - SMTP authentication mode (default: `plain`)

**NOTE:** As a special case, for development usage, if the `email-smtp-host`
key is set to `logger`, SMTP is disabled and outgoing emails are printed to the
console logger.
