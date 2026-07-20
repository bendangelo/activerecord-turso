# frozen_string_literal: true

require_relative "../test_helper"

class EdgeRecord < ActiveRecord::Base
  self.table_name = "edge_records"
end

class GenRecord < ActiveRecord::Base
  self.table_name = "gen_records"
end

class TestEdgeCases < Minitest::Test
  def setup
    ActiveRecord::Schema.define do
      create_table :edge_records, force: true do |t|
        t.string :name
        t.integer :count
        t.json :meta
        t.timestamps
      end
    end
  end

  def test_insert_all_and_upsert_all
    timestamps = { created_at: Time.now, updated_at: Time.now }
    EdgeRecord.insert_all!([
      { name: "one", count: 1, **timestamps },
      { name: "two", count: 2, **timestamps }
    ])

    assert_equal 2, EdgeRecord.count

    EdgeRecord.upsert_all([
      { id: 1, name: "one updated", count: 10, **timestamps }
    ])

    assert_equal "one updated", EdgeRecord.find(1).name
    assert_equal "two", EdgeRecord.find(2).name
  end

  def test_update_all_and_delete_all
    EdgeRecord.create!(name: "a", count: 1)
    EdgeRecord.create!(name: "b", count: 2)

    EdgeRecord.where(count: 1).update_all(name: "updated")
    assert_equal "updated", EdgeRecord.find_by(count: 1).name

    EdgeRecord.where(count: 2).delete_all
    assert_equal 1, EdgeRecord.count
  end

  def test_json_column_roundtrip
    EdgeRecord.create!(name: "json-test", meta: { tags: %w[ruby sqlite], count: 3 })
    record = EdgeRecord.find_by!(name: "json-test")
    assert_equal({ "tags" => %w[ruby sqlite], "count" => 3 }, record.meta)
  end

  def test_generated_virtual_column
    ActiveRecord::Schema.define do
      create_table :gen_records, force: true do |t|
        t.string :first_name
        t.string :last_name
        t.virtual :full_name, type: :string, as: "first_name || ' ' || last_name"
      end
    end

    skip "Virtual generated columns require experimental_features: generated_columns" unless ActiveRecordTursoTest.experimental_features.include?("generated_columns")

    record = GenRecord.create!(first_name: "Ada", last_name: "Lovelace")
    assert_equal "Ada Lovelace", record.reload.full_name
  rescue ActiveRecord::StatementInvalid => e
    skip "Generated columns not available: #{e.message}"
  end

  def test_blank_string_not_nil
    EdgeRecord.create!(name: "")
    record = EdgeRecord.find_by!(name: "")
    assert_equal "", record.name
  end
end
