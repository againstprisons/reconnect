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
