# frozen_string_literal: true

require_relative "../test_helper"

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
        datetime_col TEXT,
        date_col TEXT,
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
end
