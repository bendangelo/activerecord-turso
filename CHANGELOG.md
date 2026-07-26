# Changelog

## 0.3.0

- Pin to ActiveRecord 8.1.
- Add `Turso::Connection` as first-class per-adapter connection object.
- Release GVL during blocking database operations.
- Use native batch execution; remove Ruby-side SQL splitting.
- Add fiber-aware statement and connection ownership.
- Map `NotNullViolation` and introduce `ActiveRecordTurso::BusyError`.
- Add GitHub Actions CI matrix.
- Fix binary/blob column writes through ActiveRecord.
- Add `ActiveRecord::Tasks::TursoDatabaseTasks` for Rails `db:*` Rake tasks.
- Normalize experimental feature names (`index_method`, `generated_columns`) to native underscore format.
- Re-apply `query_timeout` on reconnect and verify with timeout tests.
- Expand type-casting and MVCC test coverage.
- Clarify embedded-only scope in README and gemspec.
