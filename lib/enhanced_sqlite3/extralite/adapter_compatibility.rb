# frozen_string_literal: true

# Makes some methods of the ActiveRecord SQLite3 adapter compatible with Extralite::Database.

module EnhancedSQLite3
  module Extralite
    module AdapterCompatibility
      def internal_exec_query(sql, name = nil, binds = [], prepare: false, async: false)
        sql = transform_query(sql)
        check_if_write_query(sql)

        mark_transaction_written_if_write(sql)

        type_casted_binds = type_casted_binds(binds)

        log(sql, name, binds, type_casted_binds, async: async) do
          with_raw_connection do |conn|
            unless prepare
              stmt = conn.prepare(sql)
              begin
                cols = stmt.columns
                unless without_prepared_statement?(binds)
                  stmt.bind(*type_casted_binds) # Added splat since Extralite doesn't accept an array argument for #bind
                end
                records = stmt.to_a_ary # Extralite uses to_a_ary rather than to_a to get a Array[Array] result
              ensure
                stmt.close
              end
            else
              stmt = @statements[sql] ||= conn.prepare(sql)
              cols = stmt.columns
              stmt.reset # Extralite uses reset rather than reset!
              stmt.bind(*type_casted_binds) # Added splat since Extralite doesn't accept an array argument for #bind
              records = stmt.to_a_ary # Extralite uses to_a_ary rather than to_a to get a Array[Array] result
            end

            # Extralite defaults to returning symbols for columns but #build_result expects strings
            build_result(columns: cols.map(&:to_s), rows: records)
          end
        end
      end

      private

      def raw_execute(sql, name, async: false, allow_retry: false, materialize_transactions: false)
        log(sql, name, async: async) do
          with_raw_connection(allow_retry: allow_retry, materialize_transactions: materialize_transactions) do |conn|
            conn.query(sql) # Extralite::Database#execute doesn't return results so use #query instead
          end
        end
      end
    end
  end
end
