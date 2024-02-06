# frozen_string_literal: true

# see: https://github.com/rails/rails/pull/49290
module EnhancedSQLite3
  module SupportsInsertReturning
    def self.apply!
      EnhancedSQLite3::Adapter.include(Adapter)
      ActiveRecord::ConnectionAdapters::SQLite3::DatabaseStatements.include(DatabaseStatements)
    end

    module Adapter
      def supports_insert_returning?
        database_version >= "3.35.0"
      end

      def return_value_after_insert?(column) # :nodoc:
        column.auto_populated?
      end

      def use_insert_returning?
        @use_insert_returning ||= @config.key?(:insert_returning) ? self.class.type_cast_config_to_boolean(@config[:insert_returning]) : true
      end

      def build_insert_sql(insert) # :nodoc:
        sql = super(insert)
        sql << " RETURNING #{insert.returning}" if insert.returning
        sql
      end
    end

    module DatabaseStatements
      def sql_for_insert(sql, pk, binds, returning) # :nodoc:
        if supports_insert_returning?
          if pk.nil?
            # Extract the table from the insert sql. Yuck.
            table_ref = extract_table_ref_from_insert_sql(sql)
            pk = primary_key(table_ref) if table_ref
          end

          returning_columns = returning || Array(pk)

          returning_columns_statement = returning_columns.map { |c| quote_column_name(c) }.join(", ")
          sql = "#{sql} RETURNING #{returning_columns_statement}" if returning_columns.any?
        end

        [sql, binds]
      end

      def extract_table_ref_from_insert_sql(sql)
        if sql =~ /into\s("[A-Za-z0-9_."\[\]\s]+"|[A-Za-z0-9_."\[\]]+)\s*/im
          $1.strip
        end
      end
    end
  end
end
