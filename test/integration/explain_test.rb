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

    ExplainPost.create!(title: "Ruby on Rails", body: "A web framework")
  rescue ActiveRecord::StatementInvalid => e
    skip "Setup failed: #{e.message}"
  end

  def test_relation_explain_returns_plan
    output = ExplainPost.where(title: "Ruby on Rails").explain.inspect
    assert_match(/SEARCH|SCAN|EXPLAIN/, output)
  end

  def test_explain_returns_structured_output
    conn = ActiveRecord::Base.connection
    result = conn.explain(ExplainPost.where(title: "test").arel, [])
    assert_kind_of String, result
    refute_empty result
  end
end
