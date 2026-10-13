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

    # Rails 8 ships every enhancement except isolated connection pools and
    # (until 8.1) `extensions:`, and this gem's adapter would replace Rails'
    # own connection configuration.
    def superseded?
      ActiveRecord::VERSION::MAJOR >= 8
    end

    def reads_extensions_config?
      ActiveRecord.version >= Gem::Version.new("8.1")
    end

    def deprecator
      @deprecator ||= ActiveSupport::Deprecation.new("1.0", "activerecord-enhancedsqlite3-adapter")
    end

    def warn_if_superseded
      return unless superseded?

      remedy = if reads_extensions_config?
        "Remove it from your Gemfile; Rails reads `pragmas:` and `extensions:` from config/database.yml itself."
      else
        "Rails reads `pragmas:` from config/database.yml itself; the gem only still loads `extensions:`, " \
          "which Rails reads itself from 8.1. Remove the gem if you do not use them."
      end
      deprecator.warn(
        "activerecord-enhancedsqlite3-adapter is not needed on Rails #{ActiveRecord::VERSION::STRING}. " \
        "#{remedy} Only `isolate_connection_pools` is still unique to the gem."
      )
    end

    def adapter_patches
      patches = []
      patches << Adapter unless superseded?
      patches << ExtensionLoading unless reads_extensions_config?
      patches << IsolatedConnectionPools if !superseded? || isolate_connection_pools?
      patches
    end
  end
end
