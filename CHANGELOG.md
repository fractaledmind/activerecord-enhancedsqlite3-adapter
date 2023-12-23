## [Unreleased]

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
