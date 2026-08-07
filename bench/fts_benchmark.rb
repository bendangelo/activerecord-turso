# frozen_string_literal: true

# Benchmark: Turso Tantivy FTS vs SQLite FTS5 — query latency comparison.
#
# Run:  ruby -Ilib bench/fts_benchmark.rb
# Env:  BENCH_RECORDS=10000   (default 10000)
#       BENCH_TIME=2          (seconds per workload, default 2)
#       BENCH_WARMUP=1        (warmup seconds, default 1)
#
# Caveats:
#   - Turso adapter is embedded-only; this measures the local Tantivy engine, not Turso cloud.
#   - FTS is WAL-only (MVCC unsupported). Both DBs run in WAL journal mode.
#   - Tantivy default tokenizer vs FTS5 unicode61 may tokenize differently;
#     the sanity check at the end flags term-hit-count mismatches.

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
$LOAD_PATH.unshift File.expand_path(__dir__, __dir__)

require "benchmark/ips"
require "fileutils"
require "json"
require "time"
require "active_record"
require "activerecord-turso"
require "sqlite3"
require "corpus"

RECORD_COUNT = ENV.fetch("BENCH_RECORDS", "10000").to_i
IPS_TIME = ENV.fetch("BENCH_TIME", "2").to_i
IPS_WARMUP = ENV.fetch("BENCH_WARMUP", "1").to_i

BENCH_DIR = File.expand_path("../tmp/bench", __dir__)
FileUtils.mkdir_p(BENCH_DIR)

TS = Time.now.strftime("%Y%m%d_%H%M%S")

# ---- Turso (Tantivy) setup ----

turso_path = File.join(BENCH_DIR, "turso_#{TS}.sqlite3")
ActiveRecord::Base.establish_connection(
  adapter: "turso",
  database: turso_path,
  pool: 1,
  timeout: 5000,
  journal_mode: "wal",
  busy_timeout: 5000,
  query_timeout: 60_000,
  experimental_features: "index_method"
)

ActiveRecord::Schema.define do
  create_table :documents, force: true do |t|
    t.string :title, null: false
    t.text :body, null: false
  end
end

class Document < ActiveRecord::Base
  self.table_name = "documents"
end

corpus = Corpus.generate(count: RECORD_COUNT)
Document.insert_all(corpus)
turso_conn = ActiveRecord::Base.connection
turso_conn.add_fts_index(:documents, [:title, :body], tokenizer: :default)

# ---- SQLite FTS5 setup ----

sqlite_path = File.join(BENCH_DIR, "sqlite_#{TS}.sqlite3")
sqlite_db = SQLite3::Database.new(sqlite_path)
sqlite_db.execute("PRAGMA journal_mode = WAL")
sqlite_db.execute(<<~SQL)
  CREATE TABLE documents (
    id INTEGER PRIMARY KEY,
    title TEXT NOT NULL,
    body TEXT NOT NULL
  )
SQL
sqlite_db.execute("CREATE VIRTUAL TABLE documents_fts USING fts5(title, body, content='documents', content_rowid='id')")
sqlite_db.execute("BEGIN")
corpus.each { |row| sqlite_db.execute("INSERT INTO documents (title, body) VALUES (?, ?)", [row[:title], row[:body]]) }
sqlite_db.execute("COMMIT")
sqlite_db.execute("INSERT INTO documents_fts(rowid, title, body) SELECT id, title, body FROM documents")

# ---- Sanity check ----

%w[database rails ruby turbine active].each do |term|
  turso_count = turso_conn.select_value("SELECT COUNT(*) FROM documents WHERE fts_match(\"title\", \"body\", '#{term}')").to_i
  sqlite_count = sqlite_db.get_first_value("SELECT COUNT(*) FROM documents d JOIN documents_fts f ON f.rowid = d.id WHERE documents_fts MATCH '#{term}'").to_i
  delta = (turso_count - sqlite_count).abs.to_f / [sqlite_count, 1].max
  warn "  sanity[#{term}]: turso=#{turso_count} sqlite=#{sqlite_count} delta=#{delta.round(3)}"
  warn "  WARN: hit counts differ by >5% for '#{term}' — tokenizers differ; results still comparable but note this." if delta > 0.05
end

# ---- Workloads ----

WORKLOADS = [
  { name: "W1 single common (database)", term: "database" },
  { name: "W2 single rare (turbine)",     term: "turbine" },
  { name: "W3 multi-term (ruby rails)",   term: "ruby rails" },
  { name: "W4 phrase (active record)",    term: "active record" },
].freeze

results = []

WORKLOADS.each do |w|
  term = w[:term]
  esc = term.gsub("'", "''")

  turso_sql = "SELECT id, title FROM documents WHERE fts_match(\"title\", \"body\", '#{esc}')"
  sqlite_sql = "SELECT d.id, d.title FROM documents d JOIN documents_fts f ON f.rowid = d.id WHERE documents_fts MATCH '#{esc}'"

  turso_ips = Benchmark.ips(warmup: IPS_WARMUP, time: IPS_TIME) do |x|
    x.report("turso") { turso_conn.select_all(turso_sql).to_a }
  end

  sqlite_ips = Benchmark.ips(warmup: IPS_WARMUP, time: IPS_TIME) do |x|
    x.report("sqlite") { sqlite_db.execute(sqlite_sql) }
  end

  turso_entry = turso_ips.entries.first
  sqlite_entry = sqlite_ips.entries.first
  ratio = turso_entry.ips.to_f / sqlite_entry.ips.to_f
  winner = ratio > 1.05 ? "turso" : (ratio < 0.95 ? "sqlite" : "tie")

  results << {
    workload: w[:name],
    turso_ips: turso_entry.ips.round(1),
    turso_error: turso_entry.error_percentage.round(1),
    sqlite_ips: sqlite_entry.ips.round(1),
    sqlite_error: sqlite_entry.error_percentage.round(1),
    ratio: ratio.round(3),
    winner: winner
  }
end

# ---- Report ----

puts "\n=== FTS Benchmark: Turso Tantivy vs SQLite FTS5 ==="
puts "Records: #{RECORD_COUNT} | Warmup: #{IPS_WARMUP}s | Time: #{IPS_TIME}s\n\n"
puts "%-30s | %-18s | %-18s | %-8s | %-6s" % ["Workload", "Turso ips (±err)", "SQLite ips (±err)", "Ratio", "Winner"]
puts "-" * 90
results.each do |r|
  puts "%-30s | %8.1f ± %-6.1f | %8.1f ± %-6.1f | %6.3f | %-6s" % [
    r[:workload], r[:turso_ips], r[:turso_error], r[:sqlite_ips], r[:sqlite_error], r[:ratio], r[:winner]
  ]
end

json_path = File.join(BENCH_DIR, "fts_benchmark_#{TS}.json")
File.write(json_path, JSON.pretty_generate(records: RECORD_COUNT, time: IPS_TIME, warmup: IPS_WARMUP, results: results, timestamp: TS))
puts "\nJSON written to #{json_path}"

# ---- Cleanup ----

ActiveRecord::Base.connection_pool.disconnect!
sqlite_db.close
FileUtils.rm_f([turso_path, "#{turso_path}-wal", "#{turso_path}-shm", sqlite_path, "#{sqlite_path}-wal", "#{sqlite_path}-shm"])
