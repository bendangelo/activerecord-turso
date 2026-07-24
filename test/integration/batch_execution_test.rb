# frozen_string_literal: true

require_relative "../test_helper"

class TestBatchExecution < Minitest::Test
  def test_batch_with_semicolon_in_string
    ActiveRecord::Base.connection.raw_connection.execute_batch(<<~SQL)
      CREATE TABLE batch_items (name TEXT);
      INSERT INTO batch_items (name) VALUES ('a;b');
      INSERT INTO batch_items (name) VALUES ('c');
    SQL
    names = ActiveRecord::Base.connection.query_values("SELECT name FROM batch_items ORDER BY name")
    assert_equal ["a;b", "c"], names
  end

  def test_batch_with_trigger
    ActiveRecord::Base.connection.raw_connection.execute_batch(<<~SQL)
      CREATE TABLE trig_users (id INTEGER PRIMARY KEY, name TEXT);
      CREATE TABLE trig_logs (message TEXT);
      CREATE TRIGGER trig_users_after_insert
      AFTER INSERT ON trig_users
      BEGIN
        INSERT INTO trig_logs (message) VALUES ('inserted');
      END;
      INSERT INTO trig_users (name) VALUES ('Alice');
    SQL
    assert_equal 1, ActiveRecord::Base.connection.query_value("SELECT COUNT(*) FROM trig_logs").to_i
  end
end
