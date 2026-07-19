# frozen_string_literal: true

require_relative "test_helper"

class TestMigrations < Minitest::Test
  def setup
    @config = { database: ":memory:", adapter: "turso" }
    @adapter = ActiveRecord::ConnectionAdapters::TursoAdapter.new(@config)
  end

  def teardown
    @adapter.disconnect!
  end

  def test_create_table
    @adapter.create_table :users do |t|
      t.string :name
      t.timestamps
    end
    columns = @adapter.columns(:users).map(&:name)
    assert_includes columns, "name"
    assert_includes columns, "created_at"
    assert_includes columns, "updated_at"
  end

  def test_rename_table
    @adapter.create_table :users do |t|
      t.string :name
    end
    @adapter.rename_table :users, :accounts
    assert @adapter.table_exists?(:accounts)
    refute @adapter.table_exists?(:users)
  end

  def test_add_and_remove_column
    @adapter.create_table :users do |t|
      t.string :name
    end
    @adapter.add_column :users, :email, :string
    assert_includes @adapter.columns(:users).map(&:name), "email"
    @adapter.remove_column :users, :email
    refute_includes @adapter.columns(:users).map(&:name), "email"
  end

  def test_change_column_default
    @adapter.create_table :users do |t|
      t.string :name
    end
    @adapter.change_column_default :users, :name, "Anonymous"
    @adapter.execute("INSERT INTO users DEFAULT VALUES")
    row = @adapter.execute("SELECT name FROM users").first
    assert_equal "Anonymous", row["name"]
  end

  def test_add_reference
    @adapter.create_table :users do |t|
      t.string :name
    end
    @adapter.create_table :posts do |t|
      t.string :title
    end
    @adapter.add_reference :posts, :user
    assert_includes @adapter.columns(:posts).map(&:name), "user_id"
  end

  def test_remove_index
    @adapter.create_table :users do |t|
      t.string :email
      t.index :email, unique: true
    end
    index_name = @adapter.indexes(:users).first.name
    @adapter.remove_index :users, name: index_name
    assert_empty @adapter.indexes(:users)
  end
end
