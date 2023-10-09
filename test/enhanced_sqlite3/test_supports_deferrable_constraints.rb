# frozen_string_literal: true

require "test_helper"

# see: https://github.com/rails/rails/pull/49376
class EnhancedSQLite3::SupportsDeferrableConstraintsTest < ActiveSupport::TestCase
  def setup
    @connection = ActiveRecord::Base.connection
  end

  def teardown
    @connection.drop_table :testings, if_exists: true
  end

  def test_deferrable_false_option_can_be_passed
    @connection.create_table :testings do |t|
      t.references :testing_parent, foreign_key: {deferrable: false}
    end

    fks = @connection.foreign_keys("testings")
    assert_equal([["testings", "testing_parents", "testing_parent_id", false]],
      fks.map { |fk| [fk.from_table, fk.to_table, fk.column, fk.deferrable] })
  end

  def test_deferrable_immediate_option_can_be_passed
    @connection.create_table :testings do |t|
      t.references :testing_parent, foreign_key: {deferrable: :immediate}
    end

    fks = @connection.foreign_keys("testings")
    assert_equal([["testings", "testing_parents", "testing_parent_id", :immediate]],
      fks.map { |fk| [fk.from_table, fk.to_table, fk.column, fk.deferrable] })
  end

  def test_deferrable_deferred_option_can_be_passed
    @connection.create_table :testings do |t|
      t.references :testing_parent, foreign_key: {deferrable: :deferred}
    end

    fks = @connection.foreign_keys("testings")
    assert_equal([["testings", "testing_parents", "testing_parent_id", :deferred]],
      fks.map { |fk| [fk.from_table, fk.to_table, fk.column, fk.deferrable] })
  end

  def test_deferrable_and_on_delete_or_on_update_option_can_be_passed
    @connection.create_table :testings do |t|
      t.references :testing_parent, foreign_key: {on_update: :cascade, on_delete: :cascade, deferrable: :immediate}
    end

    fks = @connection.foreign_keys("testings")
    assert_equal([["testings", "testing_parents", "testing_parent_id", :cascade, :cascade, :immediate]],
      fks.map { |fk| [fk.from_table, fk.to_table, fk.column, fk.on_delete, fk.on_update, fk.deferrable] })
  end
end
