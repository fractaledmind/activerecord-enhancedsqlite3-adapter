# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "rails/version"
require "sqlite3/version"

p({ ruby: RUBY_VERSION, rails: Rails::VERSION::STRING, sqlite3: SQLite3::VERSION })

require "activerecord-enhancedsqlite3-adapter"

require "minitest/autorun"

require "combustion"
# require "sqlite3"
Combustion.path = "test/combustion"
Combustion.initialize! :active_record

def dump_table_schema(*tables)
  connection = ActiveRecord::Base.connection
  old_ignore_tables = ActiveRecord::SchemaDumper.ignore_tables
  ActiveRecord::SchemaDumper.ignore_tables = connection.data_sources - tables
  stream = StringIO.new

  ActiveRecord::SchemaDumper.dump(connection, stream)
  stream.string
ensure
  ActiveRecord::SchemaDumper.ignore_tables = old_ignore_tables
end