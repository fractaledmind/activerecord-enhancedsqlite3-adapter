## [Unreleased]

- On Rails 8 and later, leave the SQLite3 adapter untouched and print a deprecation warning, since Rails ships these enhancements itself; `isolate_connection_pools` still works, and on Rails 8.0 `extensions:` are still loaded ([#24](https://github.com/fractaledmind/activerecord-enhancedsqlite3-adapter/issues/24))
- Test against Rails 7.1, 7.2, 8.0 and 8.1 in CI

## [0.8.0] - 2024-05-05

- Load `sqlpkg` extensions if listed and present ([@fractaledmind](https://github.com/fractaledmind/activerecord-enhancedsqlite3-adapter/pull/17))

## [0.7.0] - 2024-04-29

- Loosen the `sqlite3` dependency to allow for `>= 1.4.0` (including 2.x) ([@fractaledmind](https://github.com/fractaledmind/activerecord-enhancedsqlite3-adapter/pull/15))

## [0.6.0] - 2024-04-10

- Use the same busy_handler function as will be in the sqlite3-ruby gem ([@fractaledmind](https://github.com/fractaledmind/activerecord-enhancedsqlite3-adapter/pull/11))
- Allow for isolated reading and writing connection pools ([@fractaledmind](https://github.com/fractaledmind/activerecord-enhancedsqlite3-adapter/pull/12))
- Ensure that even Rails 7.0 apps can use insert returning ([@fractaledmind](https://github.com/fractaledmind/activerecord-enhancedsqlite3-adapter/pull/8))
- Load virtual columns extension only if the app is running 7.1 or less ([@npezza93](https://github.com/fractaledmind/activerecord-enhancedsqlite3-adapter/pull/7))

## [0.5.0] - 2023-12-24

- Load extensions installed via project-scoped `sqlpkg`

## [0.4.0] - 2023-12-10

- Ensure transactions are IMMEDIATE and not DEFERRED
- Ensure that our `busy_handler` is the very first configuration to be set on a connection
- Simplify and speed up our `busy_handler` implementation

## [0.3.0] - 2023-12-06

- Added a more performant implementation of the the `timeout` mechanism

## [0.2.0] - 2023-09-28

- Added support for deferrable constraints

## [0.1.0] - 2023-09-28

- Initial release
- Added support for virtual columns
- Added support setting PRAGMA statements via the `config/database.yml` file
- Added support for loading extensions via the `config/database.yml` file
