# frozen_string_literal: true

require_relative "../test_helper"

class RegressPost < ActiveRecord::Base
  self.table_name = "regress_posts"
end

class TestBulkInsertNoLock < Minitest::Test
  INSERT_COUNT = 1_000

  def setup
    @db_path = File.join(ActiveRecordTursoTest::TMP, "regress_#{Process.pid}_#{object_id}.sqlite3")
    @wal_path = "#{@db_path}-wal"
    @shm_path = "#{@db_path}-shm"

    ActiveRecord::Base.establish_connection(
      ActiveRecordTursoTest.base_config.merge(database: @db_path, pool: 5)
    )
    ActiveRecord::Schema.define do
      create_table :regress_posts, force: true do |t|
        t.string :title, null: false
        t.timestamps
      end
    end
  end

  def teardown
    ActiveRecord::Base.connection_pool&.disconnect!
    FileUtils.rm_f(@db_path)
    FileUtils.rm_f(@wal_path)
    FileUtils.rm_f(@shm_path)
    FileUtils.rm_f("#{@db_path}-journal")
  end

  def test_bulk_autocommit_inserts_leave_no_lock
    INSERT_COUNT.times do |i|
      RegressPost.create!(title: "post #{i}")
    end

    assert_equal INSERT_COUNT, RegressPost.count

    ActiveRecord::Base.connection_pool.disconnect!

    db = ::Turso::Database.new(@db_path)
    rows = db.query("SELECT COUNT(*) AS c FROM regress_posts").first["c"].to_i
    db.execute("DELETE FROM regress_posts WHERE title = 'reopen-ok'") rescue nil
    db.close
    assert_equal INSERT_COUNT, rows, "fresh connection could not read — db is still locked"
  end
end