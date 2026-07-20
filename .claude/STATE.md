# Project State
*Last updated: 2026-07-19*

## Currently Working On
Hardening the `activerecord-turso` adapter and local Turso Ruby gem for production use in a real Rails app. The test suite is now complete and green in both WAL and MVCC modes (with documented skips).

## Decisions Made
- **Goal A chosen:** production-ready real Rails app, not full upstream ActiveRecord conformance.
- **MVCC is opt-in** via `journal_mode: mvcc` in `database.yml`; default remains WAL.
- **Tests run file-backed** with env modes: `TURSO_TEST_JOURNAL_MODE=wal|mvcc`.
- **Turso gem is patched locally** at `~/Projects/turso/bindings/ruby/gem` (public `Turso::DB#prepare`, `fts` feature, `experimental_features` forwarding).
- **FTS is Tantivy-based**, not FTS5. Adapter exposes `add_fts_index`, `fts_match`, `fts_score`; supported via `CREATE INDEX ... USING fts` plus `experimental_features`.
- **Stored generated columns are unsupported**; virtual generated columns work when `experimental_features: generated_columns` is set.
- **Adapter avoids `instance_variable_get`** on the gem; public `Turso::DB#prepare` was added.
- **MVCC retry loop lives in `transaction_management.rb`**; it retries on `database schema is locked` errors.
- **MVCC has documented limitations:**
  - Custom index modules (FTS) are unsupported in MVCC mode.
  - `transaction(concurrent: true)` works for raw SQL and bulk operations but cannot support normal ActiveRecord model persistence because AR opens nested internal transactions.

## Blockers
- None currently. The suite passes in both modes.

## Next Steps
1. Push commits or open a PR if the work needs review.
2. Re-evaluate the MVCC + AR persistence limitation if a future Turso engine release supports nested/concurrent transactions differently.
3. Add CI that runs the suite in both WAL and MVCC modes, plus a run with `TURSO_TEST_EXPERIMENTAL_FEATURES=generated_columns`.
4. Continue production-readiness audit: query cache, prepared statement pool, explain output, connection pool tuning.

## Recently Modified Files
- `lib/active_record/connection_adapters/turso_adapter/schema_statements.rb` — added `fts_match`/`fts_score` helpers; fixed `add_fts_index` SQL syntax.
- `test/test_helper.rb` — default experimental features to `index_method`.
- `test/test_error_translation.rb` — removed stale standalone test.
- `test/integration/mvcc_test.rb` — added MVCC AR persistence skip test and bulk-op test.
- `test/integration/connection_management_test.rb` — new.
- `test/integration/transactions_test.rb` — new.
- `test/integration/error_translation_test.rb` — new.
- `test/integration/fts_test.rb` — new.
- `test/integration/edge_cases_test.rb` — new.

## Uncommitted Changes
None — working tree is clean.
