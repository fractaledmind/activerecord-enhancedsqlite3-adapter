# frozen_string_literal: true

require "rails/railtie"
require "enhanced_sqlite3/adapter"

module EnhancedSQLite3
  class Railtie < ::Rails::Railtie
    # Enhance the SQLite3 ActiveRecord adapter with optimized defaults
    initializer "enhanced_sqlite3.enhance_active_record_sqlite3adapter" do |app|
      ActiveSupport.on_load(:active_record_sqlite3adapter) do
        # self refers to `ActiveRecord::ConnectionAdapters::SQLite3Adapter` here,
        # so we can call .prepend
        prepend EnhancedSQLite3::Adapter
        singleton_class.prepend EnhancedSQLite3::Adapter::ClassMethods
      end
    end
  end
end
