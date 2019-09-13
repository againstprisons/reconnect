# Administration profile

re:connect has an "administration profile" feature, which allows for
centralising communications between the administration team of the penpal
network and incarcerated penpals.

This administration profile is a standard penpal profile, that has no
associated user, and does not have the "is incarcerated" flag set.

For more information, see [the commit that introduced this feature][commit].

[commit]: https://gitlab.com/againstprisons/reconnect/commit/4df2f28f

## admin-profile-id

The `admin-profile-id` configuration option is the numerical ID of the penpal
profile that should be used as the administration profile.
