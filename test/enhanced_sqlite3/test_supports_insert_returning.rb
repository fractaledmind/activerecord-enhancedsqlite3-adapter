# frozen_string_literal: true

require "test_helper"

# see: https://github.com/rails/rails/pull/49290
class EnhancedSQLite3::SupportsInsertReturningTest < ActiveSupport::TestCase
  class Default < ActiveRecord::Base
  end

  def test_fills_auto_populated_columns_on_creation
    record_with_defaults = Default.create
    assert_not_nil record_with_defaults.id
    assert_equal "Ruby on Rails", record_with_defaults.ruby_on_rails
    assert_not_nil record_with_defaults.virtual_stored_number
    assert_not_nil record_with_defaults.random_number
    assert_not_nil record_with_defaults.modified_date
    assert_not_nil record_with_defaults.modified_date_function
    assert_not_nil record_with_defaults.modified_time
    assert_not_nil record_with_defaults.modified_time_without_precision
    assert_not_nil record_with_defaults.modified_time_function
  end

  def test_schema_dump_includes_default_expression
    output = dump_table_schema("defaults")
    assert_match %r/t\.date\s+"modified_date",\s+default: -> { "CURRENT_DATE" }/, output
    assert_match %r/t\.datetime\s+"modified_time",\s+default: -> { "CURRENT_TIMESTAMP" }/, output
    assert_match %r/t\.datetime\s+"modified_time_without_precision",\s+precision: nil,\s+default: -> { "CURRENT_TIMESTAMP" }/, output
    assert_match %r/t\.datetime\s+"modified_time_with_precision_0",\s+precision: 0,\s+default: -> { "CURRENT_TIMESTAMP" }/, output
    assert_match %r/t\.integer\s+"random_number",\s+default: -> { "ABS\(RANDOM\(\) % 1000000000\)" }/, output
  end
end
