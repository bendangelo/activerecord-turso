# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
$LOAD_PATH.unshift File.expand_path("../../test", __dir__)

require "minitest/autorun"
require "minitest/around"
require "active_record"
require "activerecord-turso"

module ActiveRecordTursoTest
  ROOT = File.expand_path("..", __dir__)
  TMP  = File.join(ROOT, "tmp", "test")

  FileUtils.mkdir_p(TMP)

  def self.database_path
    File.join(TMP, "test_#{Process.pid}_#{Thread.current.object_id}.sqlite3")
  end

  def self.journal_mode
    ENV.fetch("TURSO_TEST_JOURNAL_MODE", "wal")
  end

  def self.base_config
    {
      adapter: "turso",
      database: database_path,
      pool: 5,
      timeout: 5000,
      journal_mode: journal_mode,
      busy_timeout: 5000,
      query_timeout: 30_000
    }
  end
end

ActiveRecord::Base.establish_connection(ActiveRecordTursoTest.base_config)

class Minitest::Test
  def cleanup_database
    base = ActiveRecordTursoTest.database_path.sub(/\.sqlite3$/, "")
    Dir["#{base}*"].each { |f| FileUtils.rm_f(f) }
  end

  def around
    cleanup_database
    ActiveRecord::Base.establish_connection(ActiveRecordTursoTest.base_config)
    ActiveRecord::Base.connection_pool.with_connection do |connection|
      connection.execute("PRAGMA foreign_keys = ON")
    end
    yield
  ensure
    ActiveRecord::Base.connection_pool.disconnect! if ActiveRecord::Base.connection_pool
    cleanup_database
  end
end
