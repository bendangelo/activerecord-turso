# frozen_string_literal: true

require_relative "../support/test_case"
require "bigdecimal"
require "securerandom"

class SQLite3QuotingTest < ActiveRecord::TursoConformanceTestCase
  def setup
    super
    @conn = ActiveRecord::Base.lease_connection
  end

  def test_quote_string
    assert_equal "''", @conn.quote_string("'")
  end

  def test_quote_column_name
    [@conn, @conn.class].each do |adapter|
      assert_equal '"foo"', adapter.quote_column_name("foo")
      assert_equal '"hel""lo"', adapter.quote_column_name(%{hel"lo})
    end
  end

  def test_quote_table_name
    [@conn, @conn.class].each do |adapter|
      assert_equal '"foo"', adapter.quote_table_name("foo")
      assert_equal '"foo"."bar"', adapter.quote_table_name("foo.bar")
    end
  end

  def test_type_cast_true
    assert_equal 1, @conn.type_cast(true)
  end

  def test_type_cast_false
    assert_equal 0, @conn.type_cast(false)
  end

  def test_type_cast_bigdecimal
    bd = BigDecimal("10.0")
    assert_equal bd.to_f, @conn.type_cast(bd)
  end

  def test_quote_numeric_infinity
    assert_equal "'Infinity'", @conn.quote(Float::INFINITY)
    assert_equal "'-Infinity'", @conn.quote(-Float::INFINITY)
    assert_equal "'Infinity'", @conn.quote(BigDecimal(Float::INFINITY))
    assert_equal "'-Infinity'", @conn.quote(BigDecimal(-Float::INFINITY))
  end

  def test_quote_float_nan
    assert_equal "'NaN'", @conn.quote(Float::NAN)
    assert_equal "'NaN'", @conn.quote(BigDecimal(Float::NAN))
  end
end
