# frozen_string_literal: true

module EnhancedSQLite3
  module IsolatedConnectionPools
    # Patch the #transaction method to ensure that all transactions are sent to the writing role database connection pool.
    def transaction(...)
      ActiveRecord::Base.connected_to(role: ActiveRecord.writing_role, prevent_writes: false) do
        super(...)
      end
    end

    # Patch the #log method to ensure that all log messages are tagged with the database connection name.
    def log(...)
      db_connection_name = ActiveRecord::Base.connection_db_config.name
      if Rails.logger.formatter.current_tags.include? db_connection_name
        super
      else
        Rails.logger.tagged(db_connection_name) { super }
      end
    end
  end
end
