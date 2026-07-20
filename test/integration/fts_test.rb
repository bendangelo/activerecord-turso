# frozen_string_literal: true

require_relative "../test_helper"

class FtsArticle < ActiveRecord::Base
  self.table_name = "fts_articles"
end

class TestFts < Minitest::Test
  def setup
    skip "FTS indexes are not supported in MVCC mode" if ActiveRecordTursoTest.journal_mode == "mvcc"

    ActiveRecord::Schema.define do
      create_table :fts_articles, force: true do |t|
        t.string :title, null: false
        t.text :body, null: false
      end
    end

    conn = ActiveRecord::Base.connection
    conn.add_fts_index(:fts_articles, [:title, :body], tokenizer: :default)
  rescue ActiveRecord::StatementInvalid => e
    skip "FTS requires experimental_features: ['index_method'] in database.yml: #{e.message}"
  end

  def test_fts_index_is_created
    indexes = ActiveRecord::Base.connection.fts_indexes(:fts_articles)
    assert_includes indexes, "fts_fts_articles_title_body"
  rescue ActiveRecord::StatementInvalid => e
    skip "FTS requires experimental_features: ['index_method'] in database.yml: #{e.message}"
  end

  def test_fts_match_finds_rows
    FtsArticle.create!(title: "Ruby on Rails", body: "A web framework")
    FtsArticle.create!(title: "Python scripting", body: "Another language")

    matches = FtsArticle.where(
      ActiveRecord::Base.connection.fts_match(:fts_articles, [:title, :body], "Rails")
    ).to_a

    assert_equal 1, matches.size
    assert_equal "Ruby on Rails", matches.first.title
  rescue ActiveRecord::StatementInvalid => e
    skip "FTS requires experimental_features: ['index_method'] in database.yml: #{e.message}"
  end

  def test_fts_score_orders_results
    FtsArticle.create!(title: "Ruby", body: "Ruby Ruby")
    FtsArticle.create!(title: "Ruby Python", body: "Python")

    conn = ActiveRecord::Base.connection
    match = conn.fts_match(:fts_articles, [:title, :body], "Ruby")
    score = conn.fts_score(:fts_articles, [:title, :body], "Ruby")

    results = FtsArticle.select(:id, :title, score.as("rank")).where(match).order(Arel.sql("rank ASC")).to_a

    assert_equal "Ruby", results.first.title
  rescue ActiveRecord::StatementInvalid => e
    skip "FTS requires experimental_features: ['index_method'] in database.yml: #{e.message}"
  end
end
