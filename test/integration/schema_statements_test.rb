# frozen_string_literal: true

require_relative "../test_helper"

class TestSchemaStatements < Minitest::Test
  def setup
    ActiveRecord::Schema.define do
      create_table :schema_stmt_items, force: true do |t|
        t.string :name
        t.text :body
      end
    end
  end

  def test_views_returns_empty_when_no_views
    assert_equal [], conn.views
  end

  def test_views_returns_created_view
    conn.execute("CREATE VIEW test_view AS SELECT 1 AS id")
    assert_includes conn.views, "test_view"
  end

  def test_virtual_tables_returns_empty_by_default
    assert_equal [], conn.virtual_tables
  end

  def test_create_and_drop_virtual_table
    conn.create_virtual_table(:test_fts_idx, :fts, ["title", "body"])
    assert_includes conn.virtual_tables, "test_fts_idx"

    conn.drop_virtual_table(:test_fts_idx)
    refute_includes conn.virtual_tables, "test_fts_idx"
  rescue ActiveRecord::StatementInvalid => e
    skip "FTS virtual tables may not be available in this build: #{e.message}"
  end

  def test_options_to_fts_options_empty
    assert_equal "", conn.send(:options_to_fts_options, {})
  end

  def test_options_to_fts_options_with_values
    assert_match(/tokenizer=ngram/, conn.send(:options_to_fts_options, { tokenizer: "ngram" }))
  end

  def test_indexes_excludes_fts_internals
    conn.add_index(:schema_stmt_items, :name, name: "idx_schema_stmt_items_name")

    indexes = conn.indexes(:schema_stmt_items)
    assert_includes indexes.map(&:name), "idx_schema_stmt_items_name"
    refute indexes.any? { |idx| idx.name.to_s.start_with?("fts_dir_", "sqlite_fts_") }
  end

  def test_tables_excludes_internal_tables
    conn.execute("CREATE TABLE fts_dir_bar (id INTEGER)")

    tables = conn.tables
    assert_includes tables, "schema_stmt_items"
    refute_includes tables, "fts_dir_bar"
    refute tables.any? { |t| t.start_with?("sqlite_", "__turso_internal_", "fts_dir_") }
  end

  private

  def conn
    ActiveRecord::Base.connection
  end
end
