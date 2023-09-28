# frozen_string_literal: true

require "active_record/connection_adapters/sqlite3_adapter"

module ActiveRecord
  module ConnectionAdapters
    class EnhancedSQLite3Adapter < SQLite3Adapter
    end
  end
end
