# frozen_string_literal: true

require_relative "../test_helper"

class TestSchemaOperations < Minitest::Test
  def test_create_and_drop_table
    ActiveRecord::Schema.define do
      create_table :schema_test_items, force: true do |t|
        t.string :name
      end
    end

    assert ActiveRecord::Base.connection.table_exists?(:schema_test_items)

    ActiveRecord::Schema.define do
      drop_table :schema_test_items, if_exists: true
    end

    refute ActiveRecord::Base.connection.table_exists?(:schema_test_items)
  end

  def test_add_and_remove_index
    ActiveRecord::Schema.define do
      create_table :indexed_items, force: true do |t|
        t.string :code
        t.index :code, unique: true, name: "idx_code"
      end
    end

    conn = ActiveRecord::Base.connection
    assert conn.index_exists?(:indexed_items, :code)

    conn.remove_index :indexed_items, name: "idx_code"
    refute conn.index_exists?(:indexed_items, :code)
  end

  def test_add_fts_index_helper
    skip "FTS index method is experimental in this Turso build"
    ActiveRecord::Schema.define do
      create_table :searchable_posts, force: true do |t|
        t.string :title
        t.text :body
      end
    end

    conn = ActiveRecord::Base.connection
    conn.add_fts_index(:searchable_posts, [:title, :body], tokenizer: :default)

    indexes = conn.fts_indexes(:searchable_posts)
    assert_includes indexes, "fts_searchable_posts_title_body"
  end
end
