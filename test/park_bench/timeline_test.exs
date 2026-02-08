defmodule ParkBench.TimelineTest do
  use ParkBench.DataCase, async: true

  alias ParkBench.Timeline
  alias ParkBench.Timeline.{WallPost, Comment, FeedItem}

  defp make_friends(user1, user2) do
    {low, high} =
      if user1.id < user2.id, do: {user1, user2}, else: {user2, user1}

    insert(:friendship, user: low, friend: high)
  end

  # ──────────────────────────────────────────────
  # Wall Posts
  # ──────────────────────────────────────────────

  describe "create_wall_post/1" do
    test "creates a wall post with valid attributes" do
      author = insert(:user)

      assert {:ok, post} =
               Timeline.create_wall_post(%{
                 author_id: author.id,
                 wall_owner_id: author.id,
                 body: "Hello world!"
               })

      assert post.body == "Hello world!"
      assert post.author_id == author.id
      assert post.content_hash != nil
    end

    test "creates a feed item when creating a wall post" do
      author = insert(:user)

      {:ok, post} =
        Timeline.create_wall_post(%{
          author_id: author.id,
          wall_owner_id: author.id,
          body: "Feed test post"
        })

      feed_items =
        FeedItem
        |> where([fi], fi.user_id == ^author.id and fi.item_type == "wall_post")
        |> Repo.all()

      assert length(feed_items) >= 1
      assert Enum.any?(feed_items, fn fi -> fi.content_id == post.id end)
    end

    test "returns error for empty body" do
      author = insert(:user)

      assert {:error, changeset} =
               Timeline.create_wall_post(%{
                 author_id: author.id,
                 wall_owner_id: author.id,
                 body: ""
               })

      assert errors_on(changeset).body != []
    end
  end

  describe "get_wall_post!/1" do
    test "returns the post with preloaded associations" do
      author = insert(:user)

      {:ok, post} =
        Timeline.create_wall_post(%{
          author_id: author.id,
          wall_owner_id: author.id,
          body: "Findable post"
        })

      found = Timeline.get_wall_post!(post.id)
      assert found.id == post.id
      assert found.author.id == author.id
    end

    test "raises for soft-deleted post" do
      author = insert(:user)

      {:ok, post} =
        Timeline.create_wall_post(%{
          author_id: author.id,
          wall_owner_id: author.id,
          body: "Will be deleted"
        })

      post
      |> Ecto.Changeset.change(deleted_at: DateTime.utc_now() |> DateTime.truncate(:second))
      |> Repo.update!()

      assert_raise Ecto.NoResultsError, fn ->
        Timeline.get_wall_post!(post.id)
      end
    end
  end

  describe "list_wall_posts/2" do
    test "returns posts for a wall owner" do
      owner = insert(:user)

      {:ok, _post} =
        Timeline.create_wall_post(%{
          author_id: owner.id,
          wall_owner_id: owner.id,
          body: "My post",
          ai_detection_status: "approved"
        })

      posts = Timeline.list_wall_posts(owner.id)
      assert length(posts) == 1
    end

    test "excludes hard_rejected posts but shows all other statuses including pending" do
      owner = insert(:user)

      {:ok, _approved} =
        Timeline.create_wall_post(%{
          author_id: owner.id,
          wall_owner_id: owner.id,
          body: "Approved post",
          ai_detection_status: "approved"
        })

      {:ok, _needs_review} =
        Timeline.create_wall_post(%{
          author_id: owner.id,
          wall_owner_id: owner.id,
          body: "Needs review post",
          ai_detection_status: "needs_review"
        })

      {:ok, _pending} =
        Timeline.create_wall_post(%{
          author_id: owner.id,
          wall_owner_id: owner.id,
          body: "Pending post"
        })

      {:ok, _hard_rejected} =
        Timeline.create_wall_post(%{
          author_id: owner.id,
          wall_owner_id: owner.id,
          body: "Hard rejected post",
          ai_detection_status: "hard_rejected"
        })

      posts = Timeline.list_wall_posts(owner.id)
      assert length(posts) == 3
      statuses = Enum.map(posts, & &1.ai_detection_status)
      refute "hard_rejected" in statuses
    end

    test "excludes posts from blocked users" do
      owner = insert(:user)
      blocked_user = insert(:user)
      make_friends(owner, blocked_user)

      {:ok, _} =
        Timeline.create_wall_post(%{
          author_id: blocked_user.id,
          wall_owner_id: owner.id,
          body: "Blocked user post",
          ai_detection_status: "approved"
        })

      insert(:block, blocker: owner, blocked: blocked_user)

      posts = Timeline.list_wall_posts(owner.id, viewer_id: owner.id)
      assert posts == []
    end

    test "paginates results" do
      owner = insert(:user)

      for i <- 1..5 do
        {:ok, _} =
          Timeline.create_wall_post(%{
            author_id: owner.id,
            wall_owner_id: owner.id,
            body: "Post #{i}",
            ai_detection_status: "approved"
          })
      end

      page1 = Timeline.list_wall_posts(owner.id, page: 1, per_page: 3)
      page2 = Timeline.list_wall_posts(owner.id, page: 2, per_page: 3)

      assert length(page1) == 3
      assert length(page2) == 2
    end
  end

  describe "can_post_on_wall?/2" do
    test "self can always post" do
      user = insert(:user)
      assert Timeline.can_post_on_wall?(user.id, user.id)
    end

    test "friends can post" do
      user1 = insert(:user)
      user2 = insert(:user)
      make_friends(user1, user2)
      assert Timeline.can_post_on_wall?(user1.id, user2.id)
    end

    test "non-friends cannot post" do
      user1 = insert(:user)
      user2 = insert(:user)
      refute Timeline.can_post_on_wall?(user1.id, user2.id)
    end

    test "blocked users cannot post" do
      user1 = insert(:user)
      user2 = insert(:user)
      make_friends(user1, user2)
      insert(:block, blocker: user2, blocked: user1)
      refute Timeline.can_post_on_wall?(user1.id, user2.id)
    end
  end

  describe "can_delete_post?/2" do
    test "author can delete their own post" do
      author = insert(:user)
      owner = insert(:user)

      post = %WallPost{author_id: author.id, wall_owner_id: owner.id}
      assert Timeline.can_delete_post?(author.id, post)
    end

    test "wall owner can delete posts on their wall" do
      author = insert(:user)
      owner = insert(:user)

      post = %WallPost{author_id: author.id, wall_owner_id: owner.id}
      assert Timeline.can_delete_post?(owner.id, post)
    end

    test "other users cannot delete the post" do
      author = insert(:user)
      owner = insert(:user)
      other = insert(:user)

      post = %WallPost{author_id: author.id, wall_owner_id: owner.id}
      refute Timeline.can_delete_post?(other.id, post)
    end
  end

  describe "soft_delete_post/2" do
    test "soft-deletes a post when authorized" do
      author = insert(:user)

      {:ok, post} =
        Timeline.create_wall_post(%{
          author_id: author.id,
          wall_owner_id: author.id,
          body: "To be deleted"
        })

      assert {:ok, deleted} = Timeline.soft_delete_post(post.id, author.id)
      assert deleted.deleted_at != nil
    end

    test "returns error when unauthorized" do
      author = insert(:user)
      other = insert(:user)

      {:ok, post} =
        Timeline.create_wall_post(%{
          author_id: author.id,
          wall_owner_id: author.id,
          body: "Not yours to delete"
        })

      assert {:error, :unauthorized} = Timeline.soft_delete_post(post.id, other.id)
    end
  end

  # ──────────────────────────────────────────────
  # Comments
  # ──────────────────────────────────────────────

  describe "create_comment/1" do
    test "creates a comment with valid attributes" do
      author = insert(:user)
      wall_owner = insert(:user)

      {:ok, post} =
        Timeline.create_wall_post(%{
          author_id: wall_owner.id,
          wall_owner_id: wall_owner.id,
          body: "Post for comments"
        })

      assert {:ok, comment} =
               Timeline.create_comment(%{
                 author_id: author.id,
                 commentable_type: "WallPost",
                 commentable_id: post.id,
                 body: "Nice post!"
               })

      assert comment.body == "Nice post!"
      assert comment.commentable_type == "WallPost"
    end
  end

  describe "list_comments/2" do
    test "lists comments for a commentable ordered by insertion" do
      author = insert(:user)
      post_owner = insert(:user)

      {:ok, post} =
        Timeline.create_wall_post(%{
          author_id: post_owner.id,
          wall_owner_id: post_owner.id,
          body: "Post with comments"
        })

      {:ok, c1} =
        Timeline.create_comment(%{
          author_id: author.id,
          commentable_type: "WallPost",
          commentable_id: post.id,
          body: "First comment",
          ai_detection_status: "approved"
        })

      {:ok, c2} =
        Timeline.create_comment(%{
          author_id: author.id,
          commentable_type: "WallPost",
          commentable_id: post.id,
          body: "Second comment",
          ai_detection_status: "approved"
        })

      # Set different timestamps and approved status to be listed
      earlier = DateTime.add(DateTime.utc_now(), -60, :second) |> DateTime.truncate(:second)

      Repo.get!(Comment, c1.id)
      |> Ecto.Changeset.change(ai_detection_status: "approved", inserted_at: earlier)
      |> Repo.update!()

      Repo.get!(Comment, c2.id)
      |> Ecto.Changeset.change(ai_detection_status: "approved")
      |> Repo.update!()

      comments = Timeline.list_comments("WallPost", post.id)
      assert length(comments) == 2
      assert hd(comments).body == "First comment"
    end

    test "excludes soft-deleted comments" do
      author = insert(:user)

      {:ok, post} =
        Timeline.create_wall_post(%{
          author_id: author.id,
          wall_owner_id: author.id,
          body: "Post"
        })

      {:ok, comment} =
        Timeline.create_comment(%{
          author_id: author.id,
          commentable_type: "WallPost",
          commentable_id: post.id,
          body: "Deleted comment"
        })

      comment
      |> Ecto.Changeset.change(deleted_at: DateTime.utc_now() |> DateTime.truncate(:second))
      |> Repo.update!()

      comments = Timeline.list_comments("WallPost", post.id)
      assert comments == []
    end
  end

  describe "count_comments/2" do
    test "counts non-deleted comments" do
      author = insert(:user)

      {:ok, post} =
        Timeline.create_wall_post(%{
          author_id: author.id,
          wall_owner_id: author.id,
          body: "Post for count"
        })

      {:ok, _} =
        Timeline.create_comment(%{
          author_id: author.id,
          commentable_type: "WallPost",
          commentable_id: post.id,
          body: "A comment"
        })

      {:ok, deleted_c} =
        Timeline.create_comment(%{
          author_id: author.id,
          commentable_type: "WallPost",
          commentable_id: post.id,
          body: "Deleted comment"
        })

      deleted_c
      |> Ecto.Changeset.change(deleted_at: DateTime.utc_now() |> DateTime.truncate(:second))
      |> Repo.update!()

      assert Timeline.count_comments("WallPost", post.id) == 1
    end
  end

  describe "can_delete_comment?/3" do
    test "comment author can delete" do
      comment_author = insert(:user)
      post_author = insert(:user)

      post = %WallPost{author_id: post_author.id, wall_owner_id: post_author.id}
      comment = %Comment{author_id: comment_author.id}

      assert Timeline.can_delete_comment?(comment_author.id, comment, post)
    end

    test "wall post author can delete comments" do
      comment_author = insert(:user)
      post_author = insert(:user)

      post = %WallPost{author_id: post_author.id, wall_owner_id: post_author.id}
      comment = %Comment{author_id: comment_author.id}

      assert Timeline.can_delete_comment?(post_author.id, comment, post)
    end

    test "other users cannot delete" do
      comment_author = insert(:user)
      post_author = insert(:user)
      other = insert(:user)

      post = %WallPost{author_id: post_author.id, wall_owner_id: post_author.id}
      comment = %Comment{author_id: comment_author.id}

      refute Timeline.can_delete_comment?(other.id, comment, post)
    end
  end

  describe "soft_delete_comment/2" do
    test "soft-deletes when authorized (comment author)" do
      author = insert(:user)

      {:ok, post} =
        Timeline.create_wall_post(%{
          author_id: author.id,
          wall_owner_id: author.id,
          body: "Post"
        })

      {:ok, comment} =
        Timeline.create_comment(%{
          author_id: author.id,
          commentable_type: "WallPost",
          commentable_id: post.id,
          body: "My comment"
        })

      assert {:ok, deleted} = Timeline.soft_delete_comment(comment.id, author.id)
      assert deleted.deleted_at != nil
    end

    test "returns error when unauthorized" do
      author = insert(:user)
      other = insert(:user)

      {:ok, post} =
        Timeline.create_wall_post(%{
          author_id: author.id,
          wall_owner_id: author.id,
          body: "Post"
        })

      {:ok, comment} =
        Timeline.create_comment(%{
          author_id: author.id,
          commentable_type: "WallPost",
          commentable_id: post.id,
          body: "Not your comment"
        })

      assert {:error, :unauthorized} = Timeline.soft_delete_comment(comment.id, other.id)
    end
  end

  # ──────────────────────────────────────────────
  # Likes
  # ──────────────────────────────────────────────

  describe "toggle_like/3" do
    test "likes then unlikes" do
      user = insert(:user)

      {:ok, post} =
        Timeline.create_wall_post(%{
          author_id: user.id,
          wall_owner_id: user.id,
          body: "Likeable post"
        })

      # First toggle -> like
      assert {:ok, :liked, like} = Timeline.toggle_like(user.id, "WallPost", post.id)
      assert like != nil

      # Second toggle -> unlike
      assert {:ok, :unliked, nil} = Timeline.toggle_like(user.id, "WallPost", post.id)
    end
  end

  describe "liked?/3" do
    test "returns true when liked, false when not" do
      user = insert(:user)

      {:ok, post} =
        Timeline.create_wall_post(%{
          author_id: user.id,
          wall_owner_id: user.id,
          body: "Another likeable post"
        })

      refute Timeline.liked?(user.id, "WallPost", post.id)

      Timeline.toggle_like(user.id, "WallPost", post.id)
      assert Timeline.liked?(user.id, "WallPost", post.id)
    end
  end

  describe "count_likes/2" do
    test "counts likes for a resource" do
      user1 = insert(:user)
      user2 = insert(:user)

      {:ok, post} =
        Timeline.create_wall_post(%{
          author_id: user1.id,
          wall_owner_id: user1.id,
          body: "Popular post"
        })

      Timeline.toggle_like(user1.id, "WallPost", post.id)
      Timeline.toggle_like(user2.id, "WallPost", post.id)

      assert Timeline.count_likes("WallPost", post.id) == 2
    end
  end

  # ──────────────────────────────────────────────
  # Status Updates
  # ──────────────────────────────────────────────

  describe "create_status_update/1" do
    test "creates a status update and feed item" do
      user = insert(:user)

      assert {:ok, status} =
               Timeline.create_status_update(%{user_id: user.id, body: "Feeling good!"})

      assert status.body == "Feeling good!"
      assert status.user_id == user.id

      # Should also create a feed item
      feed_items =
        FeedItem
        |> where([fi], fi.user_id == ^user.id and fi.item_type == "status_update")
        |> Repo.all()

      assert length(feed_items) >= 1
    end
  end

  describe "get_latest_status/1" do
    test "returns the most recent status" do
      user = insert(:user)
      {:ok, old} = Timeline.create_status_update(%{user_id: user.id, body: "Old status"})

      # Set old status to an earlier timestamp to ensure deterministic ordering
      earlier = DateTime.add(DateTime.utc_now(), -60, :second) |> DateTime.truncate(:second)

      Repo.get!(ParkBench.Timeline.StatusUpdate, old.id)
      |> Ecto.Changeset.change(inserted_at: earlier)
      |> Repo.update!()

      {:ok, latest} = Timeline.create_status_update(%{user_id: user.id, body: "Latest status"})

      found = Timeline.get_latest_status(user.id)
      assert found.id == latest.id
    end

    test "returns nil when no status exists" do
      user = insert(:user)
      assert Timeline.get_latest_status(user.id) == nil
    end
  end

  # ──────────────────────────────────────────────
  # Feed Items
  # ──────────────────────────────────────────────

  describe "create_feed_item/1" do
    test "creates a feed item" do
      user = insert(:user)
      content_id = Ecto.UUID.generate()

      assert {:ok, fi} =
               Timeline.create_feed_item(%{
                 user_id: user.id,
                 item_type: "wall_post",
                 content_id: content_id
               })

      assert fi.item_type == "wall_post"
    end
  end

  # ──────────────────────────────────────────────
  # News Feed
  # ──────────────────────────────────────────────

  describe "get_news_feed/2" do
    test "includes own and friends feed items" do
      user = insert(:user)
      friend = insert(:user)
      make_friends(user, friend)

      {:ok, _own_post} =
        Timeline.create_wall_post(%{
          author_id: user.id,
          wall_owner_id: user.id,
          body: "My post"
        })

      {:ok, _friend_post} =
        Timeline.create_wall_post(%{
          author_id: friend.id,
          wall_owner_id: friend.id,
          body: "Friend post"
        })

      feed = Timeline.get_news_feed(user.id)
      # Should include feed items from both users (wall_post feed items)
      assert length(feed) >= 2
    end

    test "excludes blocked users content" do
      user = insert(:user)
      blocked = insert(:user)
      make_friends(user, blocked)

      {:ok, _blocked_post} =
        Timeline.create_wall_post(%{
          author_id: blocked.id,
          wall_owner_id: blocked.id,
          body: "Blocked user post"
        })

      insert(:block, blocker: user, blocked: blocked)

      feed = Timeline.get_news_feed(user.id)

      feed_user_ids =
        Enum.map(feed, fn %{feed_item: fi} -> fi.user_id end)

      refute blocked.id in feed_user_ids
    end

    test "paginates results" do
      user = insert(:user)

      for i <- 1..5 do
        Timeline.create_wall_post(%{
          author_id: user.id,
          wall_owner_id: user.id,
          body: "Post #{i}"
        })
      end

      page1 = Timeline.get_news_feed(user.id, page: 1, per_page: 3)
      assert length(page1) <= 3
    end

    test "returns in chronological (newest first) order" do
      user = insert(:user)

      {:ok, _} =
        Timeline.create_wall_post(%{
          author_id: user.id,
          wall_owner_id: user.id,
          body: "First post"
        })

      Process.sleep(10)

      {:ok, _} =
        Timeline.create_wall_post(%{
          author_id: user.id,
          wall_owner_id: user.id,
          body: "Second post"
        })

      feed = Timeline.get_news_feed(user.id)

      if length(feed) >= 2 do
        timestamps = Enum.map(feed, fn %{feed_item: fi} -> fi.inserted_at end)
        assert timestamps == Enum.sort(timestamps, {:desc, DateTime})
      end
    end
  end

  describe "get_news_feed/2 with profile photo and cover photo updates" do
    test "loads profile_photo_updated items in feed" do
      user = insert(:user)
      friend = insert(:user)
      make_friends(user, friend)

      {:ok, photo} =
        ParkBench.Accounts.create_profile_photo(friend.id, %{
          original_url: "https://example.com/friend-photo.jpg"
        })

      feed = Timeline.get_news_feed(user.id)

      photo_items =
        Enum.filter(feed, fn %{feed_item: fi} -> fi.item_type == "profile_photo_updated" end)

      assert length(photo_items) == 1
      %{content: content} = hd(photo_items)
      assert content.id == photo.id
      assert content.original_url == "https://example.com/friend-photo.jpg"
    end

    test "loads profile_updated (cover photo) items in feed" do
      user = insert(:user)
      friend = insert(:user)
      make_friends(user, friend)

      {:ok, _profile} =
        ParkBench.Accounts.update_cover_photo(friend.id, "https://example.com/cover.jpg")

      feed = Timeline.get_news_feed(user.id)

      cover_items =
        Enum.filter(feed, fn %{feed_item: fi} -> fi.item_type == "profile_updated" end)

      assert length(cover_items) == 1
      %{content: content} = hd(cover_items)
      assert content.id == friend.id
    end
  end

  describe "count_new_feed_items_since/2" do
    test "counts feed items since a given time" do
      user = insert(:user)
      before_time = DateTime.utc_now() |> DateTime.add(-60, :second) |> DateTime.truncate(:second)

      {:ok, _} =
        Timeline.create_wall_post(%{
          author_id: user.id,
          wall_owner_id: user.id,
          body: "Recent post"
        })

      count = Timeline.count_new_feed_items_since(user.id, before_time)
      assert count >= 1
    end
  end

  # ──────────────────────────────────────────────
  # Soft Delete Cleanup
  # ──────────────────────────────────────────────

  describe "hard_delete_old_soft_deletes/1" do
    test "deletes soft-deleted posts and comments older than cutoff" do
      user = insert(:user)

      old_deleted_at =
        DateTime.utc_now() |> DateTime.add(-60 * 86400, :second) |> DateTime.truncate(:second)

      {:ok, post} =
        Timeline.create_wall_post(%{
          author_id: user.id,
          wall_owner_id: user.id,
          body: "Old deleted post"
        })

      post
      |> Ecto.Changeset.change(deleted_at: old_deleted_at)
      |> Repo.update!()

      assert {:ok, %{posts: posts_deleted, comments: _}} =
               Timeline.hard_delete_old_soft_deletes(30)

      assert posts_deleted >= 1
    end

    test "does not delete recently soft-deleted content" do
      user = insert(:user)

      {:ok, post} =
        Timeline.create_wall_post(%{
          author_id: user.id,
          wall_owner_id: user.id,
          body: "Recently deleted post"
        })

      post
      |> Ecto.Changeset.change(deleted_at: DateTime.utc_now() |> DateTime.truncate(:second))
      |> Repo.update!()

      assert {:ok, %{posts: 0, comments: 0}} = Timeline.hard_delete_old_soft_deletes(30)
    end
  end
end
