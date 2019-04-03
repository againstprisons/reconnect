# Environment variables

## Application environment

The value of the `RACK_ENV` environment variable sets the application
environment. This defaults to `production` if not set, and should remain set
to `production` when the application is deployed.

This can be set to `development`, which is recommended when working on the
codebase.

## Session secret

The value of the `SESSION_SECRET` environment variable sets the secret used for
signing of user sessions. This should be set to a sufficiently random string.

Changing this value will invalidate all existing sessions.

## Site directory

The `SITE_DIR` environment variable sets the directory used for per-site
configuration and data storage.

If a file named `config.rb` exists in this directory, it is loaded at
application initialization time.

The default location for uploaded files is the `files` subdirectory of this
directory.
