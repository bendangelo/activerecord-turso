# frozen_string_literal: true

require_relative "../test_helper"

class SelectRowsRecord < ActiveRecord::Base
  self.table_name = "select_rows_records"
end

class TestSelectRows < Minitest::Test
  def setup
    ActiveRecord::Schema.define do
      create_table :select_rows_records, force: true do |t|
        t.string :name
        t.integer :score
        t.boolean :active
        t.datetime :published_at
      end
    end
  end

  def test_select_rows_returns_raw_values
    SelectRowsRecord.create!(name: "A", score: 42, active: true, published_at: Time.now.change(usec: 0))

    rows = ActiveRecord::Base.connection.select_rows("SELECT name, score, active, published_at FROM select_rows_records")
    row = rows.first

    assert_equal "A", row[0]
    assert_equal 42, row[1]
    assert_equal 1, row[2]
    assert_kind_of String, row[3]
  end

  def test_pluck_on_computed_column
    SelectRowsRecord.create!(name: "A", score: 10)
    SelectRowsRecord.create!(name: "B", score: 20)

    values = SelectRowsRecord.pluck(Arel.sql("score * 2 AS doubled"))
    assert_equal [20, 40].sort, values.sort
  end
end
