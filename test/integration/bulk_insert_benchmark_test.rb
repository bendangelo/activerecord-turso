# frozen_string_literal: true

require_relative "../test_helper"

class BenchPost < ActiveRecord::Base
  self.table_name = "bench_posts"
end

class TestBulkInsertBenchmark < Minitest::Test
  RECORD_COUNT = ENV.fetch("BENCH_RECORD_COUNT", "10000").to_i

  def setup
    skip "set BENCH=1 to run the bulk insert benchmark" unless ENV["BENCH"]
    @db_path = File.join(ActiveRecordTursoTest::TMP, "bench_#{Process.pid}_#{object_id}.sqlite3")
    @wal_path = "#{@db_path}-wal"
    @shm_path = "#{@db_path}-shm"

    ActiveRecord::Base.establish_connection(
      ActiveRecordTursoTest.base_config.merge(database: @db_path, pool: 5)
    )
    ActiveRecord::Schema.define { create_table :bench_posts, force: true do |t|
      t.string :title, null: false
      t.timestamps
    end }
  end

  def teardown
    ActiveRecord::Base.connection_pool.disconnect! if ActiveRecord::Base.connection_pool
    FileUtils.rm_f(@db_path)
    FileUtils.rm_f(@wal_path)
    FileUtils.rm_f(@shm_path)
    FileUtils.rm_f("#{@db_path}-journal")
  end

  def test_10k_autocommit_inserts_leave_no_lock
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    RECORD_COUNT.times do |i|
      BenchPost.create!(title: "post #{i}")
    end
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
    warn "  bulk insert: %d records in %.2fs" % [RECORD_COUNT, elapsed]

    count = BenchPost.count
    assert_equal RECORD_COUNT, count

    ActiveRecord::Base.connection_pool.disconnect!

    assert_can_open_fresh_connection
  ensure
    ActiveRecord::Base.connection_pool&.disconnect!
  end

  private

  def assert_can_open_fresh_connection
    db = ::Turso::Database.new(@db_path)
    rows = db.query("SELECT COUNT(*) AS c FROM bench_posts").first["c"].to_i
    db.close
    assert_operator rows, :>, 0, "fresh connection could not read — db is still locked"
  end
end