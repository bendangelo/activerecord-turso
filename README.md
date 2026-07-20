# Activerecord-turso

ActiveRecord adapter for [Turso](https://turso.tech) (SQLite compatible db).

## Status

This adapter is under **active** development. It can run basic ActiveRecord operations against Turso today, but several production features are still being hardened. See [Limitations and Risks](#limitations-and-risks) before using it in production.

## Requirements

- Ruby >= 3.0
- ActiveRecord >= 8.0, < 8.2
- The `turso` Ruby gem

## Installation

Add to your Gemfile:

```ruby
gem "activerecord-turso"
```

Then configure `database.yml`:

```yaml
development:
  adapter: turso
  database: "path/to/db.sqlite3"
```

For an in-memory database:

```yaml
test:
  adapter: turso
  database: ":memory:"
```

## Usage

Most standard ActiveRecord operations work the same as with the SQLite3 adapter:

```ruby
class Post < ActiveRecord::Base
end

Post.create!(title: "Hello", body: "World", published: true)
```

### MVCC / BEGIN CONCURRENT

Turso supports `BEGIN CONCURRENT` for optimistic, multi-writer transactions. To opt in, pass `concurrent: true` to `transaction`:

```ruby
ActiveRecord::Base.transaction(concurrent: true) do
  user.update!(balance: user.balance - 100)
  order.create!(amount: 100)
end
```

If the commit detects a snapshot conflict, the adapter will automatically retry the block up to a configured limit with exponential backoff.

Configure retry behavior in `database.yml`:

```yaml
development:
  adapter: turso
  database: "path/to/db.sqlite3"
  turso_mvcc_max_retries: 50
  turso_mvcc_base_delay_ms: 10
```

**Important caveats:**

- `transaction(concurrent: true)` requires the same database connection to be held for the entire retry loop. Rails' connection pool may reap the connection between retries, which can silently break MVCC semantics. Use this only when you understand the pooling behavior of your app.
- `lock!`, `with_lock`, and `lock_version` are not meaningful under MVCC. Do not use them inside concurrent transactions.
- If the retry limit is exhausted, the conflict is raised as `ActiveRecord::StatementInvalid`. You must handle it in application code.

### Full-text search (Tantivy)

Turso provides full-text search through Tantivy. Use `CREATE INDEX ... USING fts`:

```sql
CREATE INDEX fts_posts ON posts USING fts (title, body);
```

From migrations:

```ruby
class AddFtsToPosts < ActiveRecord::Migration[8.1]
  def change
    add_fts_index :posts, [:title, :body], tokenizer: :default
  end
end
```

Query with the adapter helpers:

```ruby
match = ActiveRecord::Base.connection.fts_match(:posts, [:title, :body], "database")
Post.where(match)

score = ActiveRecord::Base.connection.fts_score(:posts, [:title, :body], "database")
Post.select(:id, :title, score.as("rank")).where(match).order("rank ASC")
```

Note: `fts5` virtual tables are not supported. Use `USING fts` indexes instead. This requires the `index_method` experimental feature:

```yaml
production:
  adapter: turso
  database: db/production.sqlite3
  experimental_features: "index_method"
```

### Concurrent transactions

Turso supports multi-writer concurrency with MVCC. Enable it in `database.yml`:

```yaml
development:
  adapter: turso
  database: db/dev.sqlite3
  journal_mode: mvcc
  busy_timeout: 5000

  # Enable experimental Turso features when needed (e.g., custom index methods for FTS).
  # Pass a comma-separated string or an array of feature names.
  experimental_features: "index_method"
```

Use `concurrent: true` inside the same pinned connection:

```ruby
ActiveRecord::Base.connection.transaction(concurrent: true) do
  # read-modify-write using raw SQL or bulk operations
end
```

Caveats:
- The connection must stay checked out for the whole transaction; avoid work that yields the ActiveRecord connection back to the pool.
- `busy_timeout` is used for lock waits, not MVCC snapshot conflicts. Snapshot conflicts retry with bounded backoff.
- Normal ActiveRecord model persistence (`create!`, `save!`, `update!`, `touch`) is **not supported** inside a concurrent transaction because ActiveRecord opens its own internal transaction for each model change. Use raw SQL (`execute`, `exec_query`) or bulk operations (`insert_all`, `update_all`, `update_columns`) instead.
- FTS custom index modules are not supported in MVCC mode.

## Recommended production configuration

```yaml
production:
  adapter: turso
  database: db/production.sqlite3
  journal_mode: wal            # Use mvcc only if you need concurrent writers and understand the caveats above
  pool: 5
  timeout: 5000                # busy_timeout default in milliseconds
  query_timeout: 30000           # maximum time a single query may run
  busy_timeout: 5000           # explicit busy timeout (falls back to timeout)
  experimental_features: "index_method"
```

## Limitations and Risks

The following limitations apply to the current implementation. Read this section carefully before deploying to production.

### 1. Result type metadata uses column declared types

The adapter builds column type maps from `column_decltype` metadata. This works for most column definitions but may not capture type information for computed expressions or subquery columns.

### 2. Batch SQL execution uses a simple string splitter

The adapter's batch execution path splits multi-statement SQL on semicolons. This means SQL containing semicolons inside string literals, triggers, or stored expressions may be split incorrectly. Avoid relying on multi-statement strings other than simple schema dumps.

### 3. MVCC requires opt-in and has ActiveRecord compatibility caveats

`BEGIN CONCURRENT` is powerful but breaks ActiveRecord's default assumptions:

- ActiveRecord expects transactions to commit unless the database returns an error. With `BEGIN CONCURRENT`, the commit can fail with a snapshot conflict and must be retried.
- The retry loop must run on the same connection. Rails' connection pool is not MVCC-aware and may return the connection to the pool between retries.
- Do not combine concurrent transactions with pessimistic locking (`lock!`, `with_lock`, `lock_version`).
- Normal model persistence (`create!`, `save!`, `update!`, `touch`) is unsupported inside a concurrent transaction because ActiveRecord opens an internal transaction for each model change. The error is retried a few times, then raised as `ActiveRecord::StatementInvalid`.

Only use `transaction(concurrent: true)` after testing it under your app's concurrency patterns, and prefer raw SQL or bulk operations inside the block.

### 4. Prepared statement cache is enabled with a bounded pool

The adapter uses a bounded statement pool with a default limit inherited from Rails (typically `1000`). Statements are evicted with an LRU policy and finalized against the underlying Turso connection. Set `statement_limit` in `database.yml` to tune the pool size.

### 5. ActiveRecord 8.0 support is CI-tested, not locally tested

Only ActiveRecord 8.1 is installed in the primary development environment. ActiveRecord 8.0 compatibility is validated through CI. If you run into 8.0-specific issues, please report them.

### 6. Some SQLite-specific features are unsupported or conservatively flagged

- Transaction isolation levels other than the default are reported as unsupported (`supports_transaction_isolation?` returns `false`) because Turso remote connections do not provide shared-cache read-uncommitted semantics.
- `insert_returning` is enabled only when the reported SQLite version is `>= 3.35.0`.
- `insert_on_conflict` is enabled only when the reported SQLite version is `>= 3.24.0`.

### 7. `execute_batch` in the underlying bindings is a Ruby-side fallback

The `turso` gem provides `DB#execute_batch` as a convenience that splits and executes statements one by one. It does not use a native batch API, so it carries the same semicolon-splitting risk as item 2 above.

## Development

Run the local test suite:

```bash
bundle install
bundle exec rake test
```

Run with MVCC mode:

```bash
TURSO_TEST_JOURNAL_MODE=mvcc bundle exec rake test
```

Run with generated-columns experimental feature:

```bash
TURSO_TEST_EXPERIMENTAL_FEATURES=generated_columns bundle exec rake test
```

The CI workflow in `.github/workflows/ci.yml` runs all three configurations automatically.

## License

MIT
