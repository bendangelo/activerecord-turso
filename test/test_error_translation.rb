# frozen_string_literal: true

require_relative "test_helper"

class TestErrorTranslation < Minitest::Test
  def setup
    @conn = ActiveRecord::Base.connection
    @conn.execute("CREATE TABLE error_test (id INTEGER PRIMARY KEY, other_id INTEGER UNIQUE)")
  end

  def teardown
    @conn.execute("DROP TABLE IF EXISTS error_test")
  end

  def test_unique_violation_raises_record_not_unique
    @conn.execute("INSERT INTO error_test (id, other_id) VALUES (1, 1)")
    error = assert_raises(ActiveRecord::RecordNotUnique) do
      @conn.execute("INSERT INTO error_test (id, other_id) VALUES (2, 1)")
    end
    assert_match(/unique/i, error.message)
  end

  def test_foreign_key_violation_raises_invalid_foreign_key
    @conn.execute("CREATE TABLE fk_parent (id INTEGER PRIMARY KEY)")
    @conn.execute("CREATE TABLE fk_child (parent_id INTEGER REFERENCES fk_parent(id))")
    error = assert_raises(ActiveRecord::InvalidForeignKey) do
      @conn.execute("INSERT INTO fk_child (parent_id) VALUES (999)")
    end
    assert_match(/foreign key/i, error.message)
  ensure
    @conn.execute("DROP TABLE IF EXISTS fk_child")
    @conn.execute("DROP TABLE IF EXISTS fk_parent")
  end
end
