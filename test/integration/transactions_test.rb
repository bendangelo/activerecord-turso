# frozen_string_literal: true

require_relative "../test_helper"

class TxnPost < ActiveRecord::Base
  self.table_name = "txn_posts"
end

class TxnComment < ActiveRecord::Base
  self.table_name = "txn_comments"
end

class TestTransactions < Minitest::Test
  def setup
    ActiveRecord::Schema.define do
      create_table :txn_posts, force: true do |t|
        t.string :title, null: false
        t.timestamps
      end

      create_table :txn_comments, force: true do |t|
        t.references :txn_post, null: false, foreign_key: true
        t.string :body, null: false
      end
    end
  end

  def test_transaction_commits
    ActiveRecord::Base.transaction do
      TxnPost.create!(title: "inside")
    end

    assert_equal "inside", TxnPost.first!.title
  end

  def test_transaction_rolls_back
    ActiveRecord::Base.transaction do
      TxnPost.create!(title: "will fail")
      raise ActiveRecord::Rollback
    end

    assert_nil TxnPost.find_by(title: "will fail")
  end

  def test_requires_new_creates_savepoint
    ActiveRecord::Base.transaction do
      TxnPost.create!(title: "outer")
      ActiveRecord::Base.transaction(requires_new: true) do
        TxnPost.create!(title: "inner")
        raise ActiveRecord::Rollback
      end
    end

    assert_equal ["outer"], TxnPost.pluck(:title)
  end

  def test_nested_transaction_rolls_back_outer
    assert_raises(ActiveRecord::InvalidForeignKey) do
      ActiveRecord::Base.transaction do
        post = TxnPost.create!(title: "outer post")
        TxnComment.create!(txn_post_id: post.id, body: "valid")
        # break FK inside a nested transaction
        TxnComment.create!(txn_post_id: 99_999, body: "orphan")
      end
    end

    assert_empty TxnPost.where(title: "outer post")
    assert_empty TxnComment.where(body: "valid")
  end

  def test_savepoint_release_and_reuse
    ActiveRecord::Base.transaction do
      TxnPost.create!(title: "before")
      ActiveRecord::Base.transaction(requires_new: true) do
        TxnPost.create!(title: "inside")
      end
      TxnPost.create!(title: "after")
    end

    assert_equal ["before", "inside", "after"], TxnPost.order(:id).pluck(:title)
  end
end
