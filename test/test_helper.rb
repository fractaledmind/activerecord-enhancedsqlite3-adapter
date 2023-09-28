# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "activerecord/enhanced/sqlite3/adapter"

require "minitest/autorun"
