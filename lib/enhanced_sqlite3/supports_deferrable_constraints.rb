# frozen_string_literal: true

# see: https://github.com/rails/rails/pull/49376
module EnhancedSQLite3
  module SupportsDeferrableConstraints
    def self.apply!
      EnhancedSQLite3::Adapter.include(Adapter)
      ActiveRecord::ConnectionAdapters::SQLite3::SchemaCreation.include(SchemaCreation)
    end

    module Adapter
      def supports_deferrable_constraints?
        true
      end

      FK_REGEX = /.*FOREIGN KEY\s+\("(\w+)"\)\s+REFERENCES\s+"(\w+)"\s+\("(\w+)"\)/
      DEFERRABLE_REGEX = /DEFERRABLE INITIALLY (\w+)/
      def foreign_keys(table_name)
        # SQLite returns 1 row for each column of composite foreign keys.
        fk_info = internal_exec_query("PRAGMA foreign_key_list(#{quote(table_name)})", "SCHEMA")
        # Deferred or immediate foreign keys can only be seen in the CREATE TABLE sql
        fk_defs = table_structure_sql(table_name)
          .select do |column_string|
                    column_string.start_with?("CONSTRAINT") &&
                      column_string.include?("FOREIGN KEY")
                  end
          .to_h do |fk_string|
          _, from, table, to = fk_string.match(FK_REGEX).to_a
          _, mode = fk_string.match(DEFERRABLE_REGEX).to_a
          deferred = mode&.downcase&.to_sym || false
          [[table, from, to], deferred]
        end

        grouped_fk = fk_info.group_by { |row| row["id"] }.values.each { |group| group.sort_by! { |row| row["seq"] } }
        grouped_fk.map do |group|
          row = group.first
          options = {
            on_delete: extract_foreign_key_action(row["on_delete"]),
            on_update: extract_foreign_key_action(row["on_update"]),
            deferrable: fk_defs[[row["table"], row["from"], row["to"]]]
          }

          if group.one?
            options[:column] = row["from"]
            options[:primary_key] = row["to"]
          else
            options[:column] = group.map { |row| row["from"] }
            options[:primary_key] = group.map { |row| row["to"] }
          end
          ActiveRecord::ConnectionAdapters::ForeignKeyDefinition.new(table_name, row["table"], options)
        end
      end

      def add_foreign_key(from_table, to_table, **options)
        if options[:deferrable] == true
          ActiveRecord.deprecator.warn(<<~MSG)
            `deferrable: true` is deprecated in favor of `deferrable: :immediate`, and will be removed in Rails 7.2.
          MSG

          options[:deferrable] = :immediate
        end

        assert_valid_deferrable(options[:deferrable])

        super
      end

      def table_structure_sql(table_name)
        sql = <<~SQL
          SELECT sql FROM
            (SELECT * FROM sqlite_master UNION ALL
             SELECT * FROM sqlite_temp_master)
          WHERE type = 'table' AND name = #{quote(table_name)}
        SQL

        # Result will have following sample string
        # CREATE TABLE "users" ("id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
        #                       "password_digest" varchar COLLATE "NOCASE");
        result = query_value(sql, "SCHEMA")

        return [] unless result

        # Splitting with left parentheses and discarding the first part will return all
        # columns separated with comma(,).
        columns_string = result.split("(", 2).last

        columns_string.split(",").map(&:strip)
      end

      def assert_valid_deferrable(deferrable)
        return if !deferrable || %i[immediate deferred].include?(deferrable)

        raise ArgumentError, "deferrable must be `:immediate` or `:deferred`, got: `#{deferrable.inspect}`"
      end
    end

    module SchemaCreation
      def visit_AddForeignKey(o)
        super.dup.tap do |sql|
          sql << " DEFERRABLE INITIALLY #{o.options[:deferrable].to_s.upcase}" if o.deferrable
        end
      end

      def visit_ForeignKeyDefinition(o)
        super.dup.tap do |sql|
          sql << " DEFERRABLE INITIALLY #{o.deferrable.to_s.upcase}" if o.deferrable
        end
      end
    end
  end
end
