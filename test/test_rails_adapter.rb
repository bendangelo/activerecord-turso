# frozen_string_literal: true

require_relative "test_helper"

class TestRailsAdapter < Minitest::Test
  def setup
    ActiveRecord::Base.establish_connection(
      adapter: "turso",
      database: ":memory:"
    )

    ActiveRecord::Schema.define do
      create_table :posts do |t|
        t.string :title
        t.text :body
        t.boolean :published
        t.timestamps
      end
    end

    @klass = Class.new(ActiveRecord::Base) do
      self.table_name = "posts"
    end
  end

  def test_create_and_find
    post = @klass.create!(title: "Hello", body: "World", published: true)
    found = @klass.find(post.id)
    assert_equal "Hello", found.title
    assert_equal true, found.published
  end

  def test_transaction_rollback
    @klass.transaction do
      @klass.create!(title: "Rollback")
      raise ActiveRecord::Rollback
    end
    assert_equal 0, @klass.count
  end

  def test_virtual_table_for_fts
    ActiveRecord::Schema.define do
      create_table :articles do |t|
        t.string :title
        t.text :body
      end
    end

    article = Class.new(ActiveRecord::Base) do
      self.table_name = "articles"
    end

    begin
      connection = ActiveRecord::Base.connection
      connection.create_virtual_table :articles_fts, :fts5, ["title", "body", "content='articles'"]
      article.create!(title: "Ruby concurrency", body: "A deep dive")
      matches = connection.exec_query(
        "SELECT * FROM articles_fts WHERE articles_fts MATCH ?", nil, ["ruby"]
      )
      assert_equal 1, matches.length
    rescue ActiveRecord::StatementInvalid
      skip "FTS5 not available in this Turso build"
    end
  end

  def test_update_and_delete
    post = @klass.create!(title: "First", published: false)
    post.update!(title: "Updated")
    assert_equal "Updated", post.reload.title
    post.destroy
    assert_equal 0, @klass.count
  end
end
