# frozen_string_literal: true

require_relative "lib/enhanced_sqlite3/version"

Gem::Specification.new do |spec|
  spec.name = "activerecord-enhancedsqlite3-adapter"
  spec.version = EnhancedSQLite3::VERSION
  spec.authors = ["Stephen Margheim"]
  spec.email = ["stephen.margheim@gmail.com"]

  spec.summary = "ActiveRecord adapter for SQLite that enhances the default."
  spec.description = "Back-ports generated column support, deferred foreign key support, custom foreign key support, improved default configuration, and adds support for pragma tuning and extension loading"
  spec.homepage = "https://github.com/fractaledmind/activerecord-enhancedsqlite3-adapter"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.6.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/fractaledmind/activerecord-enhancedsqlite3-adapter"
  spec.metadata["changelog_uri"] = "https://github.com/fractaledmind/activerecord-enhancedsqlite3-adapter/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .circleci appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "activerecord", ">= 7.1"
  spec.add_dependency "sqlite3", "~> 1.6"

  spec.add_development_dependency "combustion", "~> 1.3"
  spec.add_development_dependency "extralite"
  spec.add_development_dependency "railties"
  spec.add_development_dependency "minitest"
  spec.add_development_dependency "rake"
end
