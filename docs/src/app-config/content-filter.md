# Content filtering

re:connect has a content filter used for outside-to-inside correspondence.
Specifically, it is applied to the supplied text when a normal user submits new
correspondence via `/penpal/:id/correspondence/create`.

This filter can be configured in the web UI, at `/system/configuration/filter`.
It is configured by the configuration database entries prefixed with `filter`.
The format of these is documented below.

## filter-enabled

The `filter-enabled` boolean option toggles whether to use the content filter.
By default this is set to `yes`.

## filter-words

The `filter-words` configuration option is a JSON array of words that will
trigger the filter. By default, this is set to `[]` (an empty array).

Note that if the value of the `filter-words` configuration entry is malformed
JSON, and can't be parsed, it will be set to an empty array, effectively
disabling the content filter. If this is the case, a warning will be printed to
stdout when the config is refreshed, and the configuration UI will also show a
warning.
