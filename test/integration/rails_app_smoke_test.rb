# frozen_string_literal: true

require_relative "../test_helper"

class RailsAppSmokeUser < ActiveRecord::Base
  self.table_name = "smoke_users"
  has_many :posts, class_name: "RailsAppSmokePost", foreign_key: "user_id", dependent: :destroy
end

class RailsAppSmokePost < ActiveRecord::Base
  self.table_name = "smoke_posts"
  belongs_to :user, class_name: "RailsAppSmokeUser"
  has_many :comments, class_name: "RailsAppSmokeComment", foreign_key: "post_id", dependent: :destroy
end

class RailsAppSmokeComment < ActiveRecord::Base
  self.table_name = "smoke_comments"
  belongs_to :post, class_name: "RailsAppSmokePost"
end

class TestRailsAppSmoke < Minitest::Test
  def setup
    ActiveRecord::Schema.define do
      create_table :smoke_users, force: true do |t|
        t.string :email, null: false
        t.string :name
        t.timestamps
      end

      create_table :smoke_posts, force: true do |t|
        t.references :user, null: false, foreign_key: { to_table: :smoke_users }
        t.string :title, null: false
        t.text :body
        t.boolean :published, default: false, null: false
        t.datetime :published_at
        t.timestamps
      end

      create_table :smoke_comments, force: true do |t|
        t.references :post, null: false, foreign_key: { to_table: :smoke_posts }
        t.text :body, null: false
        t.timestamps
      end
    end
  end

  def test_full_crud_and_query_workflow
    user = RailsAppSmokeUser.create!(email: "alice@example.com", name: "Alice")
    post1 = user.posts.create!(title: "First", body: "Hello world", published: true, published_at: Time.now)
    user.posts.create!(title: "Draft", body: "Work in progress")

    assert_equal 2, user.posts.count
    assert_equal [post1], user.posts.where(published: true).to_a

    comment = post1.comments.create!(body: "Nice post!")
    assert_equal [comment], post1.comments.to_a

    post1.update!(title: "Updated first")
    assert_equal "Updated first", post1.reload.title

    user.destroy!
    assert_equal 0, RailsAppSmokeUser.count
    assert_equal 0, RailsAppSmokePost.count
    assert_equal 0, RailsAppSmokeComment.count
  end

  def test_transaction_rollback_and_savepoints
    RailsAppSmokeUser.create!(email: "parent@example.com")

    ActiveRecord::Base.transaction do
      RailsAppSmokeUser.create!(email: "kept@example.com")

      ActiveRecord::Base.transaction(requires_new: true) do
        RailsAppSmokeUser.create!(email: "rolled@example.com")
        raise ActiveRecord::Rollback
      end
    end

    assert_equal 2, RailsAppSmokeUser.count
    assert_nil RailsAppSmokeUser.find_by(email: "rolled@example.com")
  end
end
