# Signups and maintenance

Both of these options have quick toggle buttons in the web interface at
`/system/configuration`.

## Maintenance mode

Maintenance mode is toggled by the `maintenance` boolean config entry. When
maintenance mode is enabled, only users who have the
`site:use_during_maintenance` permission can use the site.

## Signups

Whether signups are enabled is toggled by the `signups` boolean config entry.
When signups are disabled, navigating to the signup page will present a message
saying signups are disabled. 
