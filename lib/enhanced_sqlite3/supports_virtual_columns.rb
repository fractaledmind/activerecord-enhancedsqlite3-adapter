# frozen_string_literal: true

# see: https://github.com/rails/rails/pull/49346
module EnhancedSQLite3
  module SupportsVirtualColumns
    def self.apply!
      EnhancedSQLite3::Adapter.include(Adapter)
      ActiveRecord::ConnectionAdapters::SQLite3::Column.include(Column)
      ActiveRecord::ConnectionAdapters::SQLite3::SchemaCreation.include(SchemaCreation)
      ActiveRecord::ConnectionAdapters::SQLite3::TableDefinition.include(TableDefinition)
      ActiveRecord::ConnectionAdapters::SQLite3::SchemaDumper.include(SchemaDumper)
    end

    module Adapter
      def supports_virtual_columns?
        database_version >= "3.31.0"
      end

      def new_column_from_field(table_name, field, definitions)
        default = field["dflt_value"]

        type_metadata = fetch_type_metadata(field["type"])
        default_value = extract_value_from_default(default)
        generated_type = extract_generated_type(field)

        default_function = if generated_type.present?
          default
        else
          extract_default_function(default_value, default)
        end

        rowid = is_column_the_rowid?(field, definitions) if definitions

        ActiveRecord::ConnectionAdapters::SQLite3::Column.new(
          field["name"],
          default_value,
          type_metadata,
          field["notnull"].to_i == 0,
          default_function,
          collation: field["collation"],
          auto_increment: field["auto_increment"],
          rowid: rowid,
          generated_type: generated_type
        )
      end

      def table_structure(table_name)
        structure = if supports_virtual_columns?
          internal_exec_query("PRAGMA table_xinfo(#{quote_table_name(table_name)})", "SCHEMA")
        else
          internal_exec_query("PRAGMA table_info(#{quote_table_name(table_name)})", "SCHEMA")
        end
        raise(ActiveRecord::StatementInvalid, "Could not find table '#{table_name}'") if structure.empty?
        table_structure_with_collation(table_name, structure)
      end
      alias_method :column_definitions, :table_structure

      def invalid_alter_table_type?(type, options)
        type.to_sym == :primary_key || options[:primary_key] ||
          options[:null] == false && options[:default].nil?
        options[:null] == false && options[:default].nil? ||
          (type.to_sym == :virtual && options[:stored])
      end

      GENERATED_ALWAYS_AS_REGEX = /.*"(\w+)".+GENERATED ALWAYS AS \((.+)\) (?:STORED|VIRTUAL)/i
      def table_structure_with_collation(table_name, basic_structure)
        collation_hash = {}
        auto_increments = {}
        generated_columns = {}
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

        if result
          # Splitting with left parentheses and discarding the first part will return all
          # columns separated with comma(,).
          columns_string = result.split("(", 2).last

          columns_string.split(",").each do |column_string|
            # This regex will match the column name and collation type and will save
            # the value in $1 and $2 respectively.
            collation_hash[$1] = $2 if ActiveRecord::ConnectionAdapters::SQLite3Adapter::COLLATE_REGEX =~ column_string
            auto_increments[$1] = true if ActiveRecord::ConnectionAdapters::SQLite3Adapter::PRIMARY_KEY_AUTOINCREMENT_REGEX =~ column_string
            generated_columns[$1] = $2 if GENERATED_ALWAYS_AS_REGEX =~ column_string
          end

          basic_structure.map do |column|
            column_name = column["name"]

            if collation_hash.has_key? column_name
              column["collation"] = collation_hash[column_name]
            end

            if auto_increments.has_key?(column_name)
              column["auto_increment"] = true
            end

            if generated_columns.has_key?(column_name)
              column["dflt_value"] = generated_columns[column_name]
            end

            column
          end
        else
          basic_structure.to_a
        end
      end

      def extract_generated_type(field)
        case field["hidden"]
        when 2 then :virtual
        when 3 then :stored
        end
      end
    end

    module Column
      def initialize(*, auto_increment: nil, rowid: false, generated_type: nil, **)
        super
        @generated_type = generated_type
      end

      def virtual?
        @generated_type.present?
      end

      def virtual_stored?
        virtual? && @generated_type == :stored
      end

      def has_default?
        super && !virtual?
      end
    end

    module SchemaCreation
      def add_column_options!(sql, options)
        if options[:collation]
          sql << " COLLATE \"#{options[:collation]}\""
        end

        if (as = options[:as])
          sql << " GENERATED ALWAYS AS (#{as})"

          sql << if options[:stored]
            " STORED"
          else
            " VIRTUAL"
          end
        end
        super
      end
    end

    module TableDefinition
      def new_column_definition(name, type, **options) # :nodoc:
        case type
        when :virtual
          type = options[:type]
        end

        super
      end

      def valid_column_definition_options
        super + [:as, :type, :stored]
      end
    end

    module SchemaDumper
      def prepare_column_options(column)
        spec = super

        if @connection.supports_virtual_columns? && column.virtual?
          spec[:as] = extract_expression_for_virtual_column(column)
          spec[:stored] = column.virtual_stored?
          spec = {type: schema_type(column).inspect}.merge!(spec)
        end

        spec
      end

      def extract_expression_for_virtual_column(column)
        column.default_function.inspect
      end
    end
  end
end
