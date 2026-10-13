# frozen_string_literal: true

module EnhancedSQLite3
  # Loads the `extensions:` listed in database.yml, which Rails reads itself from 8.1.
  module ExtensionLoading
    def configure_connection
      super
      configure_extensions
    end

    private

    def configure_extensions
      return if @config.fetch(:extensions, []).empty?

      @raw_connection.enable_load_extension(true)
      @config.fetch(:extensions, []).each do |extension_name|
        if extension_name.include?("/")
          raise LoadError unless Dir.exist?(".sqlpkg/#{extension_name}")
          Dir.glob(".sqlpkg/#{extension_name}/*.{dll,so,dylib}") do |extension_path|
            @raw_connection.load_extension(extension_path)
          end
        else
          require extension_name
          extension_classname = extension_name.camelize
          extension_class = extension_classname.constantize
          extension_class.load(@raw_connection)
        end
      rescue LoadError
        Dir.glob(".sqlpkg/**/*.{dll,so,dylib}") do |extension_path|
          @raw_connection.load_extension(extension_path)
        end
        Rails.logger.error("Failed to find the SQLite extension gem: #{extension_name}. Skipping...")
      rescue NameError
        Rails.logger.error("Failed to find the SQLite extension class: #{extension_classname}. Skipping...")
      end
      @raw_connection.enable_load_extension(false)
    end
  end
end
