require "active_record"
require "enhanced_sqlite3/version"
require "enhanced_sqlite3/railtie"

module EnhancedSQLite3
  Error = Class.new(StandardError)

  mattr_writer :isolate_connection_pools

  class << self
    def isolate_connection_pools?
      @isolate_connection_pools ||= @@isolate_connection_pools || false
    end

    # Rails 8 ships every enhancement except isolated connection pools, and
    # this gem's adapter would replace Rails' own connection configuration.
    def superseded?
      ActiveRecord::VERSION::MAJOR >= 8
    end

    def deprecator
      @deprecator ||= ActiveSupport::Deprecation.new("1.0", "activerecord-enhancedsqlite3-adapter")
    end

    def warn_if_superseded
      return unless superseded?

      deprecator.warn(<<~MSG.squish)
        activerecord-enhancedsqlite3-adapter is not needed on Rails #{ActiveRecord::VERSION::STRING}
        and no longer changes the SQLite3 adapter there. Remove it from your Gemfile and configure
        `pragmas:` and `extensions:` in config/database.yml instead. Only `isolate_connection_pools`
        still works on Rails 8.
      MSG
    end

    def adapter_patches
      patches = []
      patches << Adapter unless superseded?
      patches << IsolatedConnectionPools if !superseded? || isolate_connection_pools?
      patches
    end
  end
end
