# frozen_string_literal: true

require_relative "../test_helper"

class InsertUser < ActiveRecord::Base
  self.table_name = "insert_users"
end

class TestInsertReturning < Minitest::Test
  def setup
    ActiveRecord::Schema.define do
      create_table :insert_users, force: true do |t|
        t.string :name, null: false
        t.integer :score, default: 0
        t.timestamps
      end
    end
  end

  def test_create_returns_correct_id
    user = InsertUser.create!(name: "Alice")
    assert user.id
    found = InsertUser.find(user.id)
    assert_equal "Alice", found.name
  end

  def test_insert_all_creates_records
    InsertUser.insert_all!([
      { name: "A", created_at: Time.now, updated_at: Time.now },
      { name: "B", created_at: Time.now, updated_at: Time.now }
    ])

    assert_equal 2, InsertUser.count
    assert_equal ["A", "B"].sort, InsertUser.pluck(:name).sort
  end

  def test_upsert_all_updates_existing_record
    user = InsertUser.create!(name: "Alice", score: 1)

    InsertUser.upsert_all([
      { id: user.id, name: "Alice Updated", score: 99, created_at: Time.now, updated_at: Time.now }
    ])

    assert_equal "Alice Updated", user.reload.name
    assert_equal 99, user.score
  end

  def test_insert_all_with_duplicate_handling
    InsertUser.create!(name: "Alice", score: 5)

    InsertUser.insert_all([
      { name: "Bob", score: 10, created_at: Time.now, updated_at: Time.now }
    ])

    assert_equal 2, InsertUser.count
    assert_equal [5, 10], InsertUser.order(:name).pluck(:score)
  end

  def test_insert_returning_not_supported
    refute ActiveRecord::Base.connection.supports_insert_returning?
  end
end
