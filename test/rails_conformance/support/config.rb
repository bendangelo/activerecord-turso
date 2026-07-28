# frozen_string_literal: true

require "fileutils"
require "pathname"

TEST_ROOT       = File.expand_path("..", __dir__)
FIXTURES_ROOT   = File.join(TEST_ROOT, "fixtures")
MODELS_ROOT     = File.join(TEST_ROOT, "models")
SCHEMA_ROOT     = File.join(TEST_ROOT, "schema")
TMP_ROOT        = File.join(TEST_ROOT, "..", "..", "tmp", "conformance")

FileUtils.mkdir_p(TMP_ROOT)

module ActiveRecordTursoConformanceTest
  def self.database_path
    File.join(TMP_ROOT, "conformance_#{Process.pid}_#{Thread.current.object_id}.sqlite3")
  end

  def self.config
    {
      adapter: "turso",
      database: database_path,
      pool: 5,
      timeout: 5000,
      journal_mode: ENV.fetch("TURSO_TEST_JOURNAL_MODE", "wal"),
      busy_timeout: 5000,
      query_timeout: 30_000,
      experimental_features: ["index_method"]
    }
  end
end
