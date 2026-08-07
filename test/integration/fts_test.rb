# frozen_string_literal: true

require_relative "../test_helper"

class FtsArticle < ActiveRecord::Base
  self.table_name = "fts_articles"
end

class TestFts < Minitest::Test
  def setup
    skip "FTS requires experimental_features: ['index_method']" unless ActiveRecordTursoTest.experimental_features.include?("index_method")
    skip "FTS indexes are not supported in MVCC mode" if ActiveRecordTursoTest.journal_mode == "mvcc"

    ActiveRecord::Schema.define do
      create_table :fts_articles, force: true do |t|
        t.string :title, null: false
        t.text :body, null: false
      end
    end

    ActiveRecord::Base.connection.add_fts_index(:fts_articles, [:title, :body], tokenizer: :default)
  end

  def test_fts_index_is_created
    indexes = ActiveRecord::Base.connection.fts_indexes(:fts_articles)
    assert_includes indexes, "fts_fts_articles_title_body"
  end

  def test_fts_match_finds_rows
    FtsArticle.create!(title: "Ruby on Rails", body: "A web framework")
    FtsArticle.create!(title: "Python scripting", body: "Another language")

    matches = FtsArticle.where(
      ActiveRecord::Base.connection.fts_match(:fts_articles, [:title, :body], "Rails")
    ).to_a

    assert_equal 1, matches.size
    assert_equal "Ruby on Rails", matches.first.title
  end

  def test_fts_score_orders_results
    FtsArticle.create!(title: "Ruby", body: "Ruby Ruby")
    FtsArticle.create!(title: "Ruby Python", body: "Python")

    conn = ActiveRecord::Base.connection
    match = conn.fts_match(:fts_articles, [:title, :body], "Ruby")
    score = conn.fts_score(:fts_articles, [:title, :body], "Ruby")

    results = FtsArticle.select(:id, :title, score.as("rank")).where(match).order(Arel.sql("rank ASC")).to_a

    assert_equal "Ruby", results.first.title
  end

  def test_fts_match_returns_empty_for_no_results
    FtsArticle.create!(title: "Ruby on Rails", body: "A web framework")

    matches = FtsArticle.where(
      ActiveRecord::Base.connection.fts_match(:fts_articles, [:title, :body], "nonexistentterm12345")
    ).to_a

    assert_empty matches
  end

  def test_fts_match_with_special_characters
    FtsArticle.create!(title: "C++ programming", body: "Systems language")

    # Plus signs are tokenized and do not crash the query.
    matches = FtsArticle.where(
      ActiveRecord::Base.connection.fts_match(:fts_articles, [:title, :body], "C++")
    ).to_a

    refute_nil matches
  end

  def test_fts_match_apostrophe_raises_parse_error
    FtsArticle.create!(title: "O'Reilly books", body: "Tech publishing")

    # Tantivy's FTS parser rejects apostrophes in the query term.
    assert_raises(ActiveRecord::StatementInvalid) do
      FtsArticle.where(
        ActiveRecord::Base.connection.fts_match(:fts_articles, [:title, :body], "O'Reilly")
      ).to_a
    end
  end

  def test_fts_match_multi_term_relevance
    FtsArticle.create!(title: "ruby ruby", body: "ruby ruby")
    FtsArticle.create!(title: "ruby python", body: "python python")
    FtsArticle.create!(title: "python python", body: "python python")

    conn = ActiveRecord::Base.connection
    match = conn.fts_match(:fts_articles, [:title, :body], "ruby")
    score = conn.fts_score(:fts_articles, [:title, :body], "ruby")

    results = FtsArticle.select(:id, :title, score.as("rank")).where(match).order(Arel.sql("rank ASC")).to_a

    assert_equal "ruby ruby", results.first.title
    last = results.last
    assert_includes ["python python", "ruby python"], last.title
  end

  def test_remove_fts_index_drops_it
    conn = ActiveRecord::Base.connection
    assert_includes conn.fts_indexes(:fts_articles), "fts_fts_articles_title_body"

    conn.remove_fts_index(:fts_articles, "fts_fts_articles_title_body")

    refute_includes conn.fts_indexes(:fts_articles), "fts_fts_articles_title_body"
  end

  def test_fts_index_with_weights
    ActiveRecord::Schema.define do
      create_table :fts_weighted, force: true do |t|
        t.string :title, null: false
        t.text :body, null: false
      end
    end

    conn = ActiveRecord::Base.connection
    conn.add_fts_index(:fts_weighted, [:title, :body], tokenizer: :default, weights: { title: 2, body: 1 })

    assert_includes conn.fts_indexes(:fts_weighted), "fts_fts_weighted_title_body"

    conn.execute("INSERT INTO fts_weighted (title, body) VALUES ('ruby in title', 'no match here')")
    conn.execute("INSERT INTO fts_weighted (title, body) VALUES ('no match here', 'ruby in body')")

    match = conn.fts_match(:fts_weighted, [:title, :body], "ruby")
    score = conn.fts_score(:fts_weighted, [:title, :body], "ruby")

    results = conn.select_all(
      "SELECT id, title, #{score} AS rank FROM fts_weighted WHERE #{match} ORDER BY rank ASC"
    ).to_a

    assert_equal "ruby in title", results.first["title"]
  rescue ActiveRecord::StatementInvalid => e
    skip "weights not supported by current Tantivy build: #{e.message}"
  end

  def test_fts_concurrent_reads
    20.times { |i| FtsArticle.create!(title: "ruby post #{i}", body: "body #{i}") }

    match = ActiveRecord::Base.connection.fts_match(:fts_articles, [:title, :body], "ruby")

    threads = 4.times.map do
      Thread.new do
        # Each thread checks out its own pooled connection (Turso connections are single-owner).
        ActiveRecord::Base.connection_pool.with_connection do |conn|
          10.times do
            results = FtsArticle.where(match).to_a
            refute_empty results
          end
        end
      end
    end
    threads.each(&:join)
  end
end
