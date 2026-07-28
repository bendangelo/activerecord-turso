# Conformance Exceptions

This document lists Rails sqlite3 adapter tests that are intentionally skipped when running against `activerecord-turso`.

## Unsupported Turso/SQLite features

- `INSERT ... RETURNING` syntax (Turso disables this; adapter falls back to `last_insert_rowid()`).
- Shared-cache isolation / `read_uncommitted` transactions.
- `fts5` virtual tables (Turso uses Tantivy / `USING fts`).
- SQLite extension loading.
- Strict-string pragma behavior (Turso strict handling may differ).

## sqlite3 gem internals

- Tests that stub `SQLite3::Statement`, `SQLite3::Constants`, or `SQLite3::Database` directly.
- Tests that assert exact `SQLite3::Exception` class names in messages.

## Pragmas not configured in activerecord-turso

- Default `mmap_size`, `synchronous`, `journal_size_limit`, `cache_size`, `temp_store` assertions; the adapter sets only `journal_mode`, `foreign_keys`, `busy_timeout`, and `query_timeout`.

## Ported test files and their skipped tests

### `virtual_table_test.rb`

- **All tests skipped** — Turso uses Tantivy FTS instead of `fts5` virtual tables.

### `sqlite3_adapter_test.rb`

- `test_db_is_not_readonly_when_readonly_option_is_false` — Turso adapter does not implement `readonly` config option.
- `test_db_is_readonly_when_readonly_option_is_true` — Turso adapter does not implement `readonly` config option.
