# frozen_string_literal: true

require_relative "test_helper"

class TestMigrations < Minitest::Test
  def setup
    @config = { database: ":memory:", adapter: "turso" }
    @adapter = ActiveRecord::ConnectionAdapters::TursoAdapter.new(@config)
  end

  def teardown
    @adapter.disconnect!
  end

  def test_create_table
    @adapter.create_table :users do |t|
      t.string :name
      t.timestamps
    end
    columns = @adapter.columns(:users).map(&:name)
    assert_includes columns, "name"
    assert_includes columns, "created_at"
    assert_includes columns, "updated_at"
  end
end
