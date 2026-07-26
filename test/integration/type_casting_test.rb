# frozen_string_literal: true

require_relative "../test_helper"
require "securerandom"

class TypeCastingRecord < ActiveRecord::Base
  self.table_name = "type_castings"
end

class TestTypeCasting < Minitest::Test
  def setup
    ActiveRecord::Base.connection.execute(<<~SQL)
      CREATE TABLE type_castings (
        id INTEGER PRIMARY KEY,
        integer_col INTEGER,
        real_col REAL,
        decimal_col NUMERIC,
        boolean_col BOOLEAN,
        string_col TEXT,
        datetime_col DATETIME,
        date_col DATE,
        json_col JSON,
        blob_col BLOB
      )
    SQL
  end

  def teardown
    ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS type_castings")
  end

  def test_integer_roundtrip
    record = TypeCastingRecord.create!(integer_col: 42)
    assert_equal 42, record.reload.integer_col
  end

  def test_datetime_roundtrip
    now = Time.now.change(usec: 0)
    record = TypeCastingRecord.create!(datetime_col: now)
    assert_equal now, record.reload.datetime_col
  end

  def test_boolean_roundtrip
    record = TypeCastingRecord.create!(boolean_col: true)
    assert_equal true, record.reload.boolean_col
  end

  def test_json_roundtrip
    payload = { "a" => 1, "b" => "two" }
    record = TypeCastingRecord.create!(json_col: payload)
    assert_equal payload, record.reload.json_col
  end

  def test_false_roundtrip
    record = TypeCastingRecord.create!(boolean_col: false)
    record.reload
    assert_equal false, record.boolean_col
  end

  def test_nil_roundtrip
    record = TypeCastingRecord.create!(string_col: nil)
    record.reload
    assert_nil record.string_col
  end

  def test_decimal_roundtrip
    record = TypeCastingRecord.create!(decimal_col: BigDecimal("123.456"))
    record.reload
    assert_in_delta BigDecimal("123.456"), record.decimal_col, 0.001
  end

  def test_float_roundtrip
    record = TypeCastingRecord.create!(real_col: 3.14)
    record.reload
    assert_in_delta 3.14, record.real_col, 0.001
  end

  def test_date_roundtrip
    record = TypeCastingRecord.create!(date_col: Date.new(2024, 1, 2))
    record.reload
    assert_equal Date.new(2024, 1, 2), record.date_col
  end

  def test_time_roundtrip
    now = Time.now.utc.change(usec: 0)
    record = TypeCastingRecord.create!(datetime_col: now)
    record.reload
    assert_equal now, record.datetime_col
  end

  def test_blob_roundtrip
    bytes = SecureRandom.bytes(64)
    record = TypeCastingRecord.create!(blob_col: bytes)
    record.reload
    assert_equal bytes, record.blob_col
  end

  def test_json_array_roundtrip
    record = TypeCastingRecord.create!(json_col: [1, 2, 3])
    record.reload
    assert_equal [1, 2, 3], record.json_col
  end
end
