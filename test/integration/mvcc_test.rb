# frozen_string_literal: true

require_relative "../test_helper"

class MvccPost < ActiveRecord::Base
  self.table_name = "mvcc_posts"
end

class TestMvcc < Minitest::Test
  def setup
    skip "MVCC tests require TURSO_TEST_JOURNAL_MODE=mvcc" unless ActiveRecordTursoTest.journal_mode == "mvcc"

    ActiveRecord::Base.connection.execute(<<~SQL)
      CREATE TABLE IF NOT EXISTS mvcc_counters (
        id INTEGER PRIMARY KEY,
        value INTEGER NOT NULL
      )
    SQL
    ActiveRecord::Base.connection.execute("DELETE FROM mvcc_counters")
    ActiveRecord::Base.connection.execute("INSERT INTO mvcc_counters (id, value) VALUES (1, 0)")

    ActiveRecord::Schema.define do
      create_table :mvcc_posts, force: true do |t|
        t.string :title, null: false
        t.timestamps
      end
    end
  end

  def test_concurrent_transaction_basic
    ActiveRecord::Base.connection.transaction(concurrent: true) do
      value = ActiveRecord::Base.connection.query_value("SELECT value FROM mvcc_counters WHERE id = 1")
      ActiveRecord::Base.connection.execute("UPDATE mvcc_counters SET value = #{value.to_i + 1} WHERE id = 1")
    end
    final = ActiveRecord::Base.connection.query_value("SELECT value FROM mvcc_counters WHERE id = 1")
    assert_equal 1, final.to_i
  end

  def test_concurrent_transaction_isolation
    ActiveRecord::Base.connection.transaction(concurrent: true) do
      value = ActiveRecord::Base.connection.query_value("SELECT value FROM mvcc_counters WHERE id = 1")
      ActiveRecord::Base.connection.execute("UPDATE mvcc_counters SET value = #{value.to_i + 1} WHERE id = 1")
    end
    final = ActiveRecord::Base.connection.query_value("SELECT value FROM mvcc_counters WHERE id = 1")
    assert_equal 1, final.to_i
  end

  def test_concurrent_updates_no_lost_updates
    threads = 5.times.map do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do |conn|
          conn.transaction(concurrent: true) do
            value = conn.query_value("SELECT value FROM mvcc_counters WHERE id = 1").to_i
            conn.exec_query(
              "UPDATE mvcc_counters SET value = ?",
              nil,
              [
                ActiveRecord::Relation::QueryAttribute.new("value", value + 1, ActiveRecord::Type::Integer.new)
              ]
            )
          end
        end
      end
    end
    threads.each(&:join)
    final = ActiveRecord::Base.connection.query_value("SELECT value FROM mvcc_counters WHERE id = 1").to_i
    assert_equal 5, final
  end

  def test_concurrent_transaction_with_parameterized_binds
    threads = 3.times.map do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do |conn|
          conn.transaction(concurrent: true) do
            value = conn.query_value("SELECT value FROM mvcc_counters WHERE id = 1").to_i
            conn.exec_query(
              "UPDATE mvcc_counters SET value = ? WHERE id = ?",
              nil,
              [
                ActiveRecord::Relation::QueryAttribute.new("value", value + 1, ActiveRecord::Type::Integer.new),
                ActiveRecord::Relation::QueryAttribute.new("id", 1, ActiveRecord::Type::Integer.new)
              ]
            )
          end
        end
      end
    end
    threads.each(&:join)
    final = ActiveRecord::Base.connection.query_value("SELECT value FROM mvcc_counters WHERE id = 1").to_i
    assert_equal 3, final
  end

  def test_concurrent_transaction_bulk_operations
    ActiveRecord::Base.connection.transaction(concurrent: true) do
      MvccPost.insert_all([{ title: "A" }, { title: "B" }])
      MvccPost.where(title: "A").update_all(title: "C")
    end

    assert_equal ["B", "C"], MvccPost.order(:id).pluck(:title).sort
  end

  def test_concurrent_transaction_model_persistence_is_retried_then_raises
    post = MvccPost.create!(title: "initial")

    error = assert_raises(ActiveRecord::StatementInvalid) do
      ActiveRecord::Base.connection.transaction(concurrent: true) do
        post.update!(title: "updated")
      end
    end

    assert_match(/cannot start a transaction within a transaction/i, error.message)
  end
end
