# frozen_string_literal: true

# supports concatenation in default functions: https://github.com/rails/rails/pull/49287
# supports insert returning values: https://github.com/rails/rails/pull/49290
# supports configuring busy_handler: https://github.com/rails/rails/pull/49352

require "active_record/connection_adapters/sqlite3_adapter"
require "enhanced_sqlite3/supports_virtual_columns"
require "enhanced_sqlite3/supports_deferrable_constraints"
require "enhanced_sqlite3/extralite/database_compatibility"
require "enhanced_sqlite3/extralite/adapter_compatibility"

module EnhancedSQLite3
  module Adapter
    module ClassMethods
      def new_client(config)
        if config[:client] == "extralite"
          new_client_extralite(config)
        else
          super
        end
      end

      def new_client_extralite(config)
        config.delete(:results_as_hash)

        if config[:strict] == true
          raise ArgumentError, "The :strict option is not supported by the SQLite3 adapter using Extralite"
        end

        unsupported_configuration_keys = config.keys - %i[database readonly client adapter strict timeout pool]
        if unsupported_configuration_keys.any?
          Rails.logger.warn "Unsupported configuration options for SQLite3 adapter using Extralite: #{unsupported_configuration_keys}"
        end

        ::Extralite::Database.new(config[:database].to_s, read_only: config[:readonly]).tap do |database|
          database.singleton_class.prepend EnhancedSQLite3::Extralite::DatabaseCompatibility
        end
      rescue Errno::ENOENT => error
        if error.message.include?("No such file or directory")
          raise ActiveRecord::NoDatabaseError
        else
          raise
        end
      end
    end

    # Setup the Rails SQLite3 adapter instance.
    #
    # extends  https://github.com/rails/rails/blob/main/activerecord/lib/active_record/connection_adapters/sqlite3_adapter.rb#L90
    def initialize(...)
      super

      if @config[:client] == "extralite"
        singleton_class.prepend EnhancedSQLite3::Extralite::AdapterCompatibility
      else
        # Ensure that all connections default to immediate transaction mode.
        # This is necessary to prevent SQLite from deadlocking when concurrent processes open write transactions.
        # By default, SQLite opens transactions in deferred mode, which means that a transactions acquire
        # a shared lock on the database, but will attempt to upgrade that lock to an exclusive lock if/when
        # a write is attempted. Because SQLite is in the middle of a transaction, it cannot retry the transaction
        # if a BUSY exception is raised, and so it will immediately raise a SQLITE_BUSY exception without calling
        # the `busy_handler`. Because Rails only wraps writes in transactions, this means that all transactions
        # will attempt to acquire an exclusive lock on the database. Thus, under any concurrent load, you are very
        # likely to encounter a SQLITE_BUSY exception.
        # By setting the default transaction mode to immediate, SQLite will instead attempt to acquire
        # an exclusive lock as soon as the transaction is opened. If the lock cannot be acquired, it will
        # immediately call the `busy_handler` to retry the transaction. This allows concurrent processes to
        # coordinate and linearize their transactions, avoiding deadlocks.
        @connection_parameters.merge!(default_transaction_mode: :immediate)
      end
    end

    # Perform any necessary initialization upon the newly-established
    # @raw_connection -- this is the place to modify the adapter's
    # connection settings, run queries to configure any application-global
    # "session" variables, etc.
    #
    # Implementations may assume this method will only be called while
    # holding @lock (or from #initialize).
    #
    # overrides https://github.com/rails/rails/blob/main/activerecord/lib/active_record/connection_adapters/sqlite3_adapter.rb#L691
    def configure_connection
      configure_busy_handler_timeout
      check_version
      configure_pragmas
      configure_extensions

      EnhancedSQLite3::SupportsVirtualColumns.apply!
      EnhancedSQLite3::SupportsDeferrableConstraints.apply!
    end

    private

    def configure_busy_handler_timeout
      return unless @config.key?(:timeout)
      return if @config[:client] == "extralite" # extralite doesn't support busy_handler

      timeout = self.class.type_cast_config_to_integer(@config[:timeout])
      timeout_seconds = timeout.fdiv(1000)
      retry_interval = 6e-5 # 60 microseconds

      @raw_connection.busy_handler do |count|
        timed_out = false
        # keep track of elapsed time every 100 iterations (to lower load)
        if (count % 100).zero?
          # fail if we exceed the timeout value (captured from the timeout config option, converted to seconds)
          timed_out = (count * retry_interval) > timeout_seconds
        end
        if timed_out
          false # this will cause the BusyException to be raised
        else
          sleep(retry_interval)
          true
        end
      end
    end

    def configure_pragmas
      defaults = {
        # Enforce foreign key constraints
        # https://www.sqlite.org/pragma.html#pragma_foreign_keys
        # https://www.sqlite.org/foreignkeys.html
        "foreign_keys" => "ON",
        # Impose a limit on the WAL file to prevent unlimited growth
        # https://www.sqlite.org/pragma.html#pragma_journal_size_limit
        "journal_size_limit" => 64.megabytes,
        # Set the local connection cache to 2000 pages
        # https://www.sqlite.org/pragma.html#pragma_cache_size
        "cache_size" => 2000
      }
      unless @memory_database
        defaults.merge!(
          # Journal mode WAL allows for greater concurrency (many readers + one writer)
          # https://www.sqlite.org/pragma.html#pragma_journal_mode
          "journal_mode" => "WAL",
          # Set more relaxed level of database durability
          # 2 = "FULL" (sync on every write), 1 = "NORMAL" (sync every 1000 written pages) and 0 = "NONE"
          # https://www.sqlite.org/pragma.html#pragma_synchronous
          "synchronous" => "NORMAL",
          # Set the global memory map so all processes can share some data
          # https://www.sqlite.org/pragma.html#pragma_mmap_size
          # https://www.sqlite.org/mmap.html
          "mmap_size" => 128.megabytes
        )
      end
      pragmas = defaults.merge(@config.fetch(:pragmas, {}))

      pragmas.each do |key, value|
        execute("PRAGMA #{key} = #{value}", "SCHEMA")
      end
    end

    def configure_extensions
      # NOTE: Extralite enables extension loading by default and doesn't provide an API to toggle it.
      @raw_connection.enable_load_extension(true) if @raw_connection.is_a?(::SQLite3::Database)

      @config.fetch(:extensions, []).each do |extension_name|
        require extension_name
        extension_classname = extension_name.camelize
        extension_class = extension_classname.constantize
        extension_class.load(@raw_connection)
      rescue LoadError
        Rails.logger.error("Failed to find the SQLite extension gem: #{extension_name}. Skipping...")
      rescue NameError
        Rails.logger.error("Failed to find the SQLite extension class: #{extension_classname}. Skipping...")
      end
      @raw_connection.enable_load_extension(false) if @raw_connection.is_a?(::SQLite3::Database)
    end
  end
end
