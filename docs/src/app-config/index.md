# App configuration

The majority of re:connect's configuration data is stored in the database,
accessible through the `/system/configuration` endpoint of the application, or
directly through `ReConnect::Models::Config` objects (when interacting with the
application console).

Some configuration is done through environment variables - these are documented
below in the [Environment variables](./app-config/environment.md) section.

## Note on in-database configuration value substitutions

Configuration values have some substitutions performed when refreshing the
configuration from the database, before being stored in the application
instance.

The available substitutions are:

* `@SITEDIR@` - replaced with the path to the site directory
