# Penpal status options

The available options for the status of incarcerated penpals, viewable on
individual penpal pages as well as in the address book, are configurable with
the below configuration entries.

## Status options

The `penpal-statuses` configuration entry is a JSON array of valid statuses
for incarcerated penpals.

## Default status

The content of the `penpal-status-default` configuration entry is taken as the
default status to assign to new penpals, as well as penpals who have not had
a status set for some reason.

This must be set to a value that is also included in the `penpal-statuses`
array, setting it to a value that is not in that array is undefined behaviour
and could cause issues.

## Status transitions

The content of the `penpal-status-transitions` configuration entry is used to
perform automatic transitions between different penpal statuses.

The available triggers are:

* `last_correspondence` - transition when the penpal's last correspondence was
  before the time period specified in the `last_correspondence` key.
* `penpal_count` - transition when the penpal has more penpal relationships
  (excluding the relationship with the admin profile, if that exists) than is
  specified in the `penpal_count` key.

The `mode` key can be either a string, in which case the transition is applied
if the conditions for that trigger are met, or an array of strings, in which
case the transition is applied only if the conditions for all of the specified
triggers are met.

For example, to change a penpal's status from `Active` to `Inactive` after
6 months without any new correspondence, the field could be set like this:

```json
[
  {
    "from": "Active",
    "to": "Inactive",
    "when": {
      "mode": "last_correspondence",
      "last_correspondence": "6 months ago",
    }
  }
]
```

Note that the `from` and `to` values must be valid entries in the
`penpal-statuses` array.
