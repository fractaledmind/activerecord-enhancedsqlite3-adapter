# frozen_string_literal: true

# supports concatenation in default functions: https://github.com/rails/rails/pull/49287
# supports insert returning values: https://github.com/rails/rails/pull/49290
# supports configuring busy_handler: https://github.com/rails/rails/pull/49352

require "active_record/connection_adapters/sqlite3_adapter"
require "enhanced_sqlite3/supports_virtual_columns"
require "enhanced_sqlite3/supports_deferrable_constraints"

module EnhancedSQLite3
  module Adapter
    # Perform any necessary initialization upon the newly-established
    # @raw_connection -- this is the place to modify the adapter's
    # connection settings, run queries to configure any application-global
    # "session" variables, etc.
    #
    # Implementations may assume this method will only be called while
    # holding @lock (or from #initialize).
    #
    # extends https://github.com/rails/rails/blob/main/activerecord/lib/active_record/connection_adapters/sqlite3_adapter.rb#L691
    def configure_connection
      super

      configure_busy_handler_timeout
      configure_pragmas
      configure_extensions

      EnhancedSQLite3::SupportsVirtualColumns.apply!
      EnhancedSQLite3::SupportsDeferrableConstraints.apply!
    end

    private

    def configure_busy_handler_timeout
      return unless @config.key?(:timeout)
      
      timeout = self.class.type_cast_config_to_integer(@config[:timeout])
      @raw_connection.busy_handler do |count|
        timed_out = false
        # capture the start time of this blocked write
        @start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC) if count == 0
        # keep track of elapsed time every 100 iterations (to lower load)
        if count % 100 == 0
          @elapsed_time = Process.clock_gettime(Process::CLOCK_MONOTONIC) - @start_time
          # fail if we exceed the timeout value (captured from the timeout config option, converted to seconds)
          timed_out = @elapsed_time > timeout
        end
        if timed_out
          false # this will cause the BusyException to be raised
        else
          sleep 0.001 # sleep 1 millisecond (or whatever)
        end
      end
    end

    def configure_pragmas
      @config.fetch(:pragmas, []).each do |key, value|
        execute("PRAGMA #{key} = #{value}", "SCHEMA")
      end
    end

    def configure_extensions
      @raw_connection.enable_load_extension(true)
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
      @raw_connection.enable_load_extension(false)
    end
  end
end
