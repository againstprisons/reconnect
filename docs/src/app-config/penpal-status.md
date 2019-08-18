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

Currently, the only trigger for these transitions is the date of the last
correspondence sent by a penpal.

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
