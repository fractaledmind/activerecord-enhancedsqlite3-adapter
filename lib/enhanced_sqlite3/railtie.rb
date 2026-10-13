# frozen_string_literal: true

require "rails/railtie"
require "enhanced_sqlite3/adapter"
require "enhanced_sqlite3/extension_loading"
require "enhanced_sqlite3/isolated_connection_pools"
require "enhanced_sqlite3/resolver"

module EnhancedSQLite3
  class Railtie < ::Rails::Railtie
    config.enhanced_sqlite3 = ActiveSupport::OrderedOptions.new

    initializer "enhanced_sqlite3.config" do
      config.enhanced_sqlite3.each do |name, value|
        EnhancedSQLite3.public_send(:"#{name}=", value)
      end
    end

    initializer "enhanced_sqlite3.deprecator" do |app|
      app.deprecators[:enhanced_sqlite3] = EnhancedSQLite3.deprecator
      EnhancedSQLite3.warn_if_superseded
    end

    # Enhance the SQLite3 ActiveRecord adapter with optimized defaults
    initializer "enhanced_sqlite3.enhance_active_record_sqlite3adapter" do |app|
      ActiveSupport.on_load(:active_record_sqlite3adapter) do
        # self refers to `SQLite3Adapter` here
        EnhancedSQLite3.adapter_patches.each { |patch| prepend patch }
      end
    end

    # Enhance the application with isolated reading and writing connection pools
    initializer "enhanced_sqlite3.setup_isolated_connection_pools" do |app|
      next unless EnhancedSQLite3.isolate_connection_pools?

      ActiveSupport.on_load(:active_record) do
        # self refers to `ActiveRecord::Base` here
        env_configs = configurations.configs_for env_name: Rails.env
        remaining_configs = configurations.configurations.reject { |configuration| env_configs.include? configuration }
        if env_configs.one?
          config = env_configs.first
          reader = ActiveRecord::DatabaseConfigurations::HashConfig.new(
            Rails.env, "reader", config.configuration_hash.merge(readonly: true)
          )
          writer = ActiveRecord::DatabaseConfigurations::HashConfig.new(
            Rails.env, "writer", config.configuration_hash.merge(pool: 1)
          )

          # Replace the single production configuration with two separate reader and writer configurations
          self.configurations = remaining_configs + [writer, reader]
        else
          reader = env_configs.find { |config| config.name == "reader" }
          writer = env_configs.find { |config| config.name == "writer" }

          # Ensure that that there is a reader and writer configuration for the current Rails environment
          raise Error.new("#{Rails.env} has #{env_configs.size} configurations") unless reader && writer
        end

        connects_to database: {writing: :writer, reading: :reader}
      end

      # Since we aren't actually using separate databases, only separate connections,
      # we don't need to ensure that requests "read your own writes" with a `delay`
      config.active_record.database_selector = {delay: 0}
      # Use our custom resolver to ensure that benchmarking requests are sent to the reading database connection
      config.active_record.database_resolver = EnhancedSQLite3::Resolver
      # Keep Rails' default resolver context
      config.active_record.database_resolver_context = ActiveRecord::Middleware::DatabaseSelector::Resolver::Session
    end
  end
end
