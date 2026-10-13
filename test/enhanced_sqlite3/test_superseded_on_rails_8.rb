# frozen_string_literal: true

require "test_helper"

class EnhancedSQLite3::SupersededOnRails8Test < ActiveSupport::TestCase
  def adapter_ancestors
    ActiveRecord::ConnectionAdapters::SQLite3Adapter.ancestors
  end

  if EnhancedSQLite3.superseded?
    def test_leaves_the_rails_adapter_unpatched
      assert_not_includes adapter_ancestors, EnhancedSQLite3::Adapter
      assert_not_includes adapter_ancestors, EnhancedSQLite3::IsolatedConnectionPools
    end

    def test_keeps_isolated_connection_pools_when_enabled
      EnhancedSQLite3.isolate_connection_pools = true
      assert_equal [EnhancedSQLite3::IsolatedConnectionPools], EnhancedSQLite3.adapter_patches
    ensure
      EnhancedSQLite3.isolate_connection_pools = false
      EnhancedSQLite3.instance_variable_set(:@isolate_connection_pools, nil)
    end

    def test_warns_that_the_gem_is_not_needed
      assert_deprecated(/not needed on Rails/, EnhancedSQLite3.deprecator) do
        EnhancedSQLite3.warn_if_superseded
      end
    end
  else
    def test_enhances_the_rails_adapter
      assert_includes adapter_ancestors, EnhancedSQLite3::Adapter
      assert_includes adapter_ancestors, EnhancedSQLite3::IsolatedConnectionPools
    end

    def test_does_not_warn
      assert_not_deprecated(EnhancedSQLite3.deprecator) do
        EnhancedSQLite3.warn_if_superseded
      end
    end
  end
end
