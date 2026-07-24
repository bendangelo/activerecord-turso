# Changelog

## 0.3.0

- Pin to ActiveRecord 8.1.
- Add `Turso::Connection` as first-class per-adapter connection object.
- Release GVL during blocking database operations.
- Use native batch execution; remove Ruby-side SQL splitting.
- Add fiber-aware statement and connection ownership.
- Map `NotNullViolation` and introduce `ActiveRecordTurso::BusyError`.
- Add GitHub Actions CI matrix.
