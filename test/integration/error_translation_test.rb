# frozen_string_literal: true

require_relative "../test_helper"

class UniqueRecord < ActiveRecord::Base
  self.table_name = "unique_records"
end

class ForeignRecord < ActiveRecord::Base
  self.table_name = "foreign_records"
end

class TestErrorTranslation < Minitest::Test
  def setup
    ActiveRecord::Schema.define do
      create_table :parents, force: true do |t|
        t.string :name
      end

      create_table :unique_records, force: true do |t|
        t.string :code, null: false
        t.index :code, unique: true
      end

      create_table :foreign_records, force: true do |t|
        t.references :parent, null: false, foreign_key: true
      end
    end
  end

  def test_unique_violation_raises_record_not_unique
    UniqueRecord.create!(code: "abc")
    assert_raises(ActiveRecord::RecordNotUnique) do
      UniqueRecord.create!(code: "abc")
    end
  end

  def test_foreign_key_violation_raises_invalid_foreign_key
    assert_raises(ActiveRecord::InvalidForeignKey) do
      ForeignRecord.create!(parent_id: 9_999)
    end
  end

  def test_not_null_violation_raises_not_null_violation
    assert_raises(ActiveRecord::NotNullViolation) do
      ActiveRecord::Base.connection.execute("INSERT INTO unique_records (code) VALUES (NULL)")
    end
  end

  def test_busy_error_is_mapped_as_busy_error_not_deadlocked
    assert ActiveRecordTurso::BusyError < ActiveRecord::StatementInvalid
    assert ActiveRecordTurso::Error < ActiveRecord::StatementInvalid
  end

  def test_translate_exception_maps_not_a_database_to_no_database_error
    error = translate(Turso::NotADatabaseException.new("not a database"))
    assert_instance_of ActiveRecord::NoDatabaseError, error
  end

  def test_translate_exception_maps_busy_snapshot_to_serialization_failure
    error = translate(Turso::BusySnapshotException.new("snapshot conflict"))
    assert_instance_of ActiveRecord::SerializationFailure, error
  end

  def test_translate_exception_maps_busy_to_busy_error
    error = translate(Turso::BusyException.new("database is locked"))
    assert_instance_of ActiveRecordTurso::BusyError, error
  end

  def test_translate_exception_maps_readonly_to_read_only_record
    error = translate(Turso::ReadonlyException.new("attempt to write a readonly database"))
    assert_instance_of ActiveRecord::ReadOnlyRecord, error
  end

  def test_translate_exception_maps_io_to_statement_invalid
    error = translate(Turso::IoException.new("disk I/O error"))
    assert_instance_of ActiveRecord::StatementInvalid, error
  end

  def test_translate_exception_maps_corrupt_to_statement_invalid
    error = translate(Turso::CorruptException.new("database disk image is malformed"))
    assert_instance_of ActiveRecord::StatementInvalid, error
  end

  def test_translate_exception_maps_database_full_to_statement_invalid
    error = translate(Turso::DatabaseFullException.new("database or disk is full"))
    assert_instance_of ActiveRecord::StatementInvalid, error
  end

  def test_translate_exception_maps_interrupt_to_query_canceled
    error = translate(Turso::InterruptException.new("interrupted"))
    assert_instance_of ActiveRecord::QueryCanceled, error
  end

  def test_translate_exception_maps_misuse_to_statement_invalid
    error = translate(Turso::MisuseException.new("misuse"))
    assert_instance_of ActiveRecord::StatementInvalid, error
  end

  def test_translate_exception_maps_generic_turso_exception_to_connection_failed
    error = translate(Turso::Exception.new("generic failure"))
    assert_instance_of ActiveRecord::ConnectionFailed, error
  end

  def test_translate_exception_maps_unknown_constraint_to_statement_invalid
    error = translate(Turso::ConstraintException.new("some other constraint error"))
    assert_instance_of ActiveRecord::StatementInvalid, error
  end

  def test_retryable_connection_error_includes_turso_exceptions
    assert ActiveRecord::Base.connection.send(:retryable_connection_error?, Turso::Exception.new("x"))
  end

  def test_retryable_query_error_includes_turso_exceptions
    assert ActiveRecord::Base.connection.send(:retryable_query_error?, Turso::Exception.new("x"))
  end

  def test_not_a_database_file_raises_no_database_error
    path = File.join(ActiveRecordTursoTest::TMP, "not_a_db_#{Process.pid}.bin")
    header = "\x00" * 4096
    header[0, 16] = "not a sqlite db!".ljust(16, "\x00")
    header[16, 2] = [4096].pack("n")
    File.binwrite(path, header)

    ActiveRecord::Base.establish_connection(
      adapter: "turso",
      database: path,
      pool: 5,
      timeout: 5000,
      journal_mode: "delete",
      busy_timeout: 5000,
      query_timeout: 30_000
    )

    error = assert_raises(ActiveRecord::NoDatabaseError) do
      ActiveRecord::Base.connection.execute("SELECT 1")
    end
    assert_match(/not a database/i, error.message)
  ensure
    ActiveRecord::Base.establish_connection(ActiveRecordTursoTest.base_config)
    FileUtils.rm_f(path) if path
  end

  private

  def translate(exception)
    ActiveRecord::Base.connection.send(
      :translate_exception,
      exception,
      message: exception.message,
      sql: "SELECT 1",
      binds: []
    )
  end
end
