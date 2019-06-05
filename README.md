# re:connect

## Repository info

re:connect lives on GitLab.com at [againstprisons/reconnect][gitlab]. If you
wish to contribute or report an issue, GitLab is the place to do it. There is
also a read-only mirror on GitHub at [peopleagainstprisons/reconnect][github].

[gitlab]: https://gitlab.com/againstprisons/reconnect
[github]: https://github.com/peopleagainstprisons/reconnect

## Setting up

```
$ bundle install
$ npm install
$ npm run build
```

[Set up your environment variables][envvars], then:

```
$ bundle exec rake db:migrate
```

To run the app, run both of these commands in separate windows:

```
$ bundle exec puma -v
$ bundle exec sidekiq -r ./config/reconnect.rb
```

[envvars]: https://againstprisons.gitlab.io/reconnect/app-config/environment.html

## License

re:connect is licensed under the MIT license, see [the LICENSE file](./LICENSE)
for more details.
