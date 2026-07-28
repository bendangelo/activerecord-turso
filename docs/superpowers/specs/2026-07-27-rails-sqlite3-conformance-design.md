# Rails sqlite3 Adapter Conformance for activerecord-turso

**Date:** 2026-07-27
**Status:** Approved, ready for implementation plan

## Goal

Make `activerecord-turso` a trustworthy local/embedded ActiveRecord adapter by proving it satisfies the same adapter contract as Rails' built-in sqlite3 adapter. We do this by porting the Rails sqlite3 adapter conformance tests, running them against the Turso adapter, and fixing or documenting every divergence.

## Scope

- Local/embedded Turso only. Remote `libsql://` URLs and cloud authentication are explicitly out of scope.
- Runtime `sqlite3` gem dependency is removed from the gemspec.
- The `sqlite3` gem may remain as a test-only dependency if the conformance harness needs it.
- Tests that exercise SQLite features unsupported by Turso are skipped and listed in a public exceptions document.

## Architecture

### Test directory layout

```
test/
  test_*.rb                         # existing unit/adapter tests
  integration/                      # existing Turso-specific integration tests
  rails_conformance/                # ported Rails sqlite3 adapter contract tests
    support/                        # vendored Rails test helper modules
    sqlite3/                        # sqlite3 adapter conformance test files
      connection_test.rb
      migration_test.rb
      schema_test.rb
      statement_test.rb
      ...
  dummy/                            # tiny Rails app for end-to-end smoke tests (future)
    config/
    app/models/
```

### Rake tasks

- `rake test` — existing unit and integration tests (fast, Turso-feature focused).
- `rake test:conformance` — ported Rails sqlite3 adapter contract tests.
- `rake test:rails` — full dummy-app smoke test (future, optional tier).

This keeps the fast suite fast and lets CI run the heavier conformance suite separately.

## Vendored Rails support files

The Rails sqlite3 adapter tests depend on support modules from `activerecord/test/cases/helper.rb`, `abstract_unit.rb`, and adapter-specific base classes. The minimal set required by the sqlite3 adapter tests will be vendored under `test/rails_conformance/support/`.

Responsibilities of the support files:

- Load `activerecord-turso` instead of the default adapter.
- Configure the test database to use the `turso` adapter.
- Provide adapter-specific skip helpers, e.g., `skip_unless_sqlite3_feature`.
- Keep Rails version metadata in a header comment.

The entire Rails test tree will not be vendored; only the pieces the sqlite3 adapter tests actually require.

## Conformance test selection and skip policy

Port these test categories first, because they cover the contract most ActiveRecord and Rails apps depend on:

1. Connection management and statement execution.
2. Schema statements (tables, columns, indexes, defaults, foreign keys, views).
3. Type casting and parameter binding.
4. Migrations.
5. Transactions and savepoints.
6. Database tasks (`create`, `drop`, `purge`, `structure_dump`, `structure_load`).
7. Quoting and `sanitize_sql` behavior.

Classification of every failing test:

- **Real bug** — fix in the adapter and add a regression test if the conformance test is too broad.
- **Unsupported Turso feature** — skip with `skip "Turso does not support ..."` and add it to `CONFORMANCE_EXCEPTIONS.md`.
- **sqlite3 gem internals** — rewrite to use the adapter public API, or skip if irrelevant to the contract.

## Turso-specific coverage to retain and expand

The existing `test/integration/` suite remains the place for Turso-specific behavior:

- Reconnect after native connection close (already added).
- MVCC / `BEGIN CONCURRENT` behavior.
- Native batch execution edge cases.
- `query_timeout` and `interrupt` cancellation.
- FTS helper methods and `USING fts` indexes.
- Fiber-aware connection ownership.

These are the differentiating features of the adapter and need direct coverage.

## Dependency cleanup

- Remove `sqlite3` from `activerecord-turso.gemspec` runtime dependencies.
- Add `sqlite3` to the `Gemfile` under a `:test` or `:conformance` group only, if needed.
- Update `README.md` to clarify that `sqlite3` is not required at runtime.

## Continuous integration

Add a third CI job to `.github/workflows/ci.yml`:

- `conformance` — runs `bundle exec rake test:conformance` in WAL mode.
- Optionally run with `TURSO_TEST_JOURNAL_MODE=mvcc` once the suite is stable.

Existing unit/integration jobs stay unchanged.

## Acceptance criteria

- `rake test:conformance` runs the ported Rails sqlite3 adapter tests.
- All real-bug failures are fixed or have linked follow-up issues.
- Every skipped test has a documented reason in `test/rails_conformance/CONFORMANCE_EXCEPTIONS.md`.
- `rake test` still passes with no new failures or skips.
- CI includes a conformance job that passes.
- The gemspec no longer lists `sqlite3` as a runtime dependency.
