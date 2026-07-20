# frozen_string_literal: true

require_relative "../test_helper"

class ExplainPost < ActiveRecord::Base
  self.table_name = "explain_posts"
end

class TestExplain < Minitest::Test
  def setup
    skip "FTS indexes are not supported in MVCC mode" if ActiveRecordTursoTest.journal_mode == "mvcc"

    ActiveRecord::Schema.define do
      create_table :explain_posts, force: true do |t|
        t.string :title, null: false
        t.text :body, null: false
      end
    end

    conn = ActiveRecord::Base.connection
    conn.add_index(:explain_posts, :title, name: "idx_explain_posts_title")
    conn.add_fts_index(:explain_posts, [:title, :body], tokenizer: :default)

    ExplainPost.create!(title: "Ruby on Rails", body: "A web framework")
  rescue ActiveRecord::StatementInvalid => e
    skip "FTS explain requires experimental_features: ['index_method'] in database.yml: #{e.message}"
  end

  def test_relation_explain_returns_plan
    output = ExplainPost.where(title: "Ruby on Rails").explain.inspect
    assert_match(/SEARCH|SCAN|EXPLAIN/, output)
  end

  def test_fts_explain_shows_index_method
    skip "FTS indexes are not supported in MVCC mode" if ActiveRecordTursoTest.journal_mode == "mvcc"

    conn = ActiveRecord::Base.connection
    match = conn.fts_match(:explain_posts, [:title, :body], "Rails")
    output = ExplainPost.where(match).explain.inspect

    assert_match(/QUERY INDEX METHOD fts/i, output)
  end
end
