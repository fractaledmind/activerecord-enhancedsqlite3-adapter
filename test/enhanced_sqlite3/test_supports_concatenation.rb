# frozen_string_literal: true

require "test_helper"

# see: https://github.com/rails/rails/pull/49287
class EnhancedSQLite3::SupportsConcatenationTest < ActiveSupport::TestCase
  class Default < ActiveRecord::Base
  end
  
  def test_change_column_default_supports_default_function_with_concatenation_operator
    record_with_defaults = Default.create
    assert_equal "'Ruby ' || 'on ' || 'Rails'", Default.columns_hash["ruby_on_rails"].default_function
    assert_equal "Ruby on Rails", record_with_defaults.ruby_on_rails
  end
end
