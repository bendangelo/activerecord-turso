# Project State
*Last updated: 2026-07-19*

## Currently Working On
Hardening the `activerecord-turso` adapter and local Turso Ruby gem for production use in a real Rails app. We are mid-discipline switch: moving from manual Ruby exploration to proper file-based test coverage, with a newly discovered MVCC concurrency blocker under investigation.

## Decisions Made
- **Goal A chosen:** production-ready real Rails app, not full upstream ActiveRecord conformance.
- **MVCC is opt-in** via `journal_mode: mvcc` in `database.yml`; default remains WAL.
- **Tests run file-backed** with env modes: `TURSO_TEST_JOURNAL_MODE=wal|mvcc`.
- **Turso gem is patched locally** at `~/Projects/turso/bindings/ruby/gem` (public `Turso::DB#prepare`, `fts` feature, `experimental_features` forwarding).
- **FTS is Tantivy-based**, not FTS5. Adapter exposes `add_fts_index`, `fts_match`, `fts_score`; supported via `CREATE INDEX ... USING fts` plus `experimental_features`.
- **Stored generated columns are unsupported**; virtual generated columns work when `experimental_features: generated_columns` is set.
- **Adapter avoids `instance_variable_get`** on the gem; public `Turso::DB#prepare` was added.
- **MVCC retry loop lives in `transaction_management.rb`**; it retries on `database schema is locked` errors.

## Blockers
- [ ] **MVCC + ActiveRecord model persistence is broken inside `transaction(concurrent: true)`.**
  - Raw SQL and bulk operations (`insert_all`, `update_all`, `update_columns`, `update_column`) work.
  - ActiveRecord model persistence (`Post.create!`, `post.update!`, `post.touch`) fails because AR wraps them in nested internal transactions via `with_transaction_returning_status`, causing Turso error: `Transaction error: cannot start a transaction within a transaction`.
  - Temporary confirmation: `post.class.transaction { post.update_columns(...) }` also fails inside a concurrent transaction.

## Next Steps
1. Revert or stabilize any temporary exploratory changes in `transaction_management.rb` and `turso_adapter.rb`.
2. Write a failing test file proving the MVCC + AR persistence bug.
3. Decide whether to fix MVCC + AR persistence, document it as unsupported, or provide an alternative API; then adjust code/tests accordingly.
4. Write thorough test files for connection management, CRUD/associations, transactions/savepoints, type casting, FTS, error translation, and edge cases.
5. Run the full suite in both WAL and MVCC modes and commit.

## Recently Modified Files
- `lib/active_record/connection_adapters/turso_adapter/connection_management.rb` — fixed `active?` returning `nil` instead of `false` after disconnect (uncommitted).

## Uncommitted Changes
- `M lib/active_record/connection_adapters/turso_adapter/connection_management.rb` (`active?` fix).
- `?? docs/` (new, content unknown).
