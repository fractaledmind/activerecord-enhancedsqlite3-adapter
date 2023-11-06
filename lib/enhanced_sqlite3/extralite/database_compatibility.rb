# frozen_string_literal: true

# Implements some methods to make Extralite::Database compatible enough with
# SQLite3::Database to be used by ActiveRecord's SQLite adapter.

module EnhancedSQLite3
  module Extralite
    module DatabaseCompatibility
      def transaction(mode = :deferred)
        execute "BEGIN #{mode.to_s.upcase} TRANSACTION"

        if block_given?
          abort = false
          begin
            yield self
          rescue StandardError
            abort = true
            raise
          ensure
            abort and rollback or commit
          end
        end

        true
      end

      def commit
        execute "COMMIT TRANSACTION"
      end

      def rollback
        execute "ROLLBACK TRANSACTION"
      end

      # NOTE: Extralite only supports UTF-8 encoding while the sqlite3 gem can use UTF-16
      # if utf16: true is passed to the Database initializer.
      def encoding
        "UTF-8"
      end

      # NOTE: The sqlite3 gem appears to support both busy_timeout= and busy_timeout
      # The ActiveRecord adapter #configure_connection method uses the latter, which
      # could potentially be changed, allowing us to get rid of the monkey patch.
      def busy_timeout(timeout)
        self.busy_timeout = timeout
      end

      def readonly?
        read_only?
      end
    end
  end
end
