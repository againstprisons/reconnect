# re:connect

re:connect is the user-facing site and automation suite powering the
[Prisoner Correspondence Network][pcn]. re:connect is developed and
maintained by [People Against Prisons Aotearoa][papa]'s Technology
Working Group.

[pcn]: https://pcn.nz
[papa]: https://papa.org.nz

## Setting up

Install the dependencies and build the static assets:

```
$ bundle install
$ npm install
$ npm run build
```

[Set up your environment variables][envvars], then run the database migrations:

```
$ bundle exec rake db:migrate
```

[envvars]: https://againstprisons.gitlab.io/reconnect/app-config/environment.html

## Running

To run the application, run both of these commands:

```
$ bundle exec puma -v
$ bundle exec sidekiq -r ./config/reconnect.rb
```

The first runs the application web server (and will echo the port number that
the application is running on), and the second runs the background job
worker.

## Sponsors

Development of re:connect has been funded in part by [Ruby New Zealand][rbnz],
through their 2020 Community Grants program.

[![Ruby New Zealand logo][rbnz_logo]][rbnz]

[rbnz]: https://ruby.nz
[rbnz_logo]: https://papa-opensource-assets.ams3.cdn.digitaloceanspaces.com/rubynz-logo.png

## License

re:connect is licensed under the MIT license. See the LICENSE file in the root
of the repository for details.