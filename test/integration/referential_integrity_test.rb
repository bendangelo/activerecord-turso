# frozen_string_literal: true

require_relative "../test_helper"

class RefUser < ActiveRecord::Base
  self.table_name = "ref_users"
end

class RefPost < ActiveRecord::Base
  self.table_name = "ref_posts"
  belongs_to :user, class_name: "RefUser"
end

class TestReferentialIntegrity < Minitest::Test
  def setup
    ActiveRecord::Schema.define do
      create_table :ref_users, force: true do |t|
        t.string :name
      end

      create_table :ref_posts, force: true do |t|
        t.references :user, null: false, foreign_key: { to_table: :ref_users }
      end
    end
  end

  def test_disable_referential_integrity_allows_violation
    RefUser.create!(name: "Alice")

    ActiveRecord::Base.connection.disable_referential_integrity do
      ActiveRecord::Base.connection.execute("INSERT INTO ref_posts (user_id) VALUES (99999)")
    end

    assert_equal 1, RefPost.count
  end

  def test_foreign_keys_restored_after_block
    RefUser.create!(name: "Alice")

    ActiveRecord::Base.connection.disable_referential_integrity do
      ActiveRecord::Base.connection.execute("INSERT INTO ref_posts (user_id) VALUES (99999)")
    end

    assert_raises(ActiveRecord::InvalidForeignKey) do
      ActiveRecord::Base.connection.execute("INSERT INTO ref_posts (user_id) VALUES (99999)")
    end
  end

  def test_disable_referential_integrity_defers_foreign_keys_when_set
    conn = ActiveRecord::Base.connection
    conn.execute("PRAGMA defer_foreign_keys = ON")
    original_defer = conn.query_value("PRAGMA defer_foreign_keys")

    RefUser.create!(name: "Alice")

    conn.disable_referential_integrity do
      conn.execute("INSERT INTO ref_posts (user_id) VALUES (99999)")
    end

    assert_equal original_defer.inspect, conn.query_value("PRAGMA defer_foreign_keys").inspect
    assert_equal 1, conn.query_value("PRAGMA foreign_keys")
    assert_equal 1, RefPost.count
  end

  def test_disable_referential_integrity_when_defer_foreign_keys_is_off
    conn = ActiveRecord::Base.connection
    conn.execute("PRAGMA defer_foreign_keys = OFF")
    original_defer = conn.query_value("PRAGMA defer_foreign_keys")

    RefUser.create!(name: "Alice")

    conn.disable_referential_integrity do
      conn.execute("INSERT INTO ref_posts (user_id) VALUES (99999)")
    end

    assert_equal original_defer.inspect, conn.query_value("PRAGMA defer_foreign_keys").inspect
    assert_equal 1, conn.query_value("PRAGMA foreign_keys")
    assert_equal 1, RefPost.count
  end
end
