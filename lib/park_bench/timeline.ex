defmodule ParkBench.Timeline do
  @moduledoc "Wall posts, comments, likes, status updates, and the chronological feed"

  import Ecto.Query
  alias ParkBench.Repo
  alias ParkBench.Timeline.{WallPost, Comment, Like, StatusUpdate, FeedItem}
  alias ParkBench.Social
  alias ParkBench.Privacy.Block
  alias ParkBench.AIDetection
  alias ParkBench.RateLimiter

  # === Wall Posts ===

  def create_wall_post(attrs) do
    with :ok <- RateLimiter.check(attrs[:author_id] || attrs["author_id"], :create_wall_post) do
      %WallPost{}
      |> WallPost.changeset(attrs)
      |> Repo.insert()
      |> case do
        {:ok, post} ->
          create_feed_item(%{
            user_id: post.author_id,
            item_type: "wall_post",
            content_id: post.id
          })

          if post.body && post.body != "" do
            AIDetection.check_text(post.author_id, "wall_post", post.id, post.body)
          end

          # Broadcast to wall owner
          if post.author_id != post.wall_owner_id do
            Phoenix.PubSub.broadcast(
              ParkBench.PubSub,
              "user:#{post.wall_owner_id}",
              {:new_wall_post, post}
            )
          end

          # Fan out to friends' feeds
          friend_ids = Social.list_friends(post.author_id) |> Enum.map(& &1.id)

          for friend_id <- friend_ids do
            Phoenix.PubSub.broadcast(
              ParkBench.PubSub,
              "feed:#{friend_id}",
              {:new_feed_item, post.id}
            )
          end

          {:ok, post}

        error ->
          error
      end
    end
  end

  def get_wall_post!(id) do
    WallPost
    |> where([p], p.id == ^id and is_nil(p.deleted_at))
    |> Repo.one!()
    |> Repo.preload([:author, :wall_owner])
  end

  def list_wall_posts(wall_owner_id, opts \\ []) do
    page = Keyword.get(opts, :page, 1)
    per_page = Keyword.get(opts, :per_page, 20)
    viewer_id = Keyword.get(opts, :viewer_id)

    blocked_ids = if viewer_id, do: blocked_user_ids(viewer_id), else: []

    WallPost
    |> where([p], p.wall_owner_id == ^wall_owner_id and is_nil(p.deleted_at))
    |> where([p], p.ai_detection_status not in ["hard_rejected"])
    |> then(fn q ->
      if blocked_ids != [] do
        where(q, [p], p.author_id not in ^blocked_ids)
      else
        q
      end
    end)
    |> order_by([p], desc: p.inserted_at)
    |> offset(^((page - 1) * per_page))
    |> limit(^per_page)
    |> preload([:author, :wall_owner])
    |> Repo.all()
  end

  def can_post_on_wall?(author_id, wall_owner_id) do
    cond do
      author_id == wall_owner_id ->
        true

      Social.blocked?(author_id, wall_owner_id) ->
        false

      true ->
        ParkBench.Privacy.can_post_on_wall?(author_id, wall_owner_id)
    end
  end

  def can_delete_post?(user_id, post) do
    user_id == post.author_id || user_id == post.wall_owner_id
  end

  def soft_delete_post(post_id, user_id) do
    post = get_wall_post!(post_id)

    if can_delete_post?(user_id, post) do
      post
      |> Ecto.Changeset.change(deleted_at: DateTime.utc_now() |> DateTime.truncate(:second))
      |> Repo.update()
    else
      {:error, :unauthorized}
    end
  end

  # === Comments (Polymorphic) ===

  def create_comment(attrs) do
    with :ok <- RateLimiter.check(attrs[:author_id] || attrs["author_id"], :create_comment) do
      %Comment{}
      |> Comment.changeset(attrs)
      |> Repo.insert()
      |> case do
        {:ok, comment} ->
          AIDetection.check_text(comment.author_id, "comment", comment.id, comment.body)

          Phoenix.PubSub.broadcast(
            ParkBench.PubSub,
            "#{comment.commentable_type}:#{comment.commentable_id}",
            {:new_comment, comment}
          )

          {:ok, comment}

        error ->
          error
      end
    end
  end

  def list_comments(commentable_type, commentable_id) do
    Comment
    |> where([c], c.commentable_type == ^commentable_type and c.commentable_id == ^commentable_id)
    |> where([c], is_nil(c.deleted_at))
    |> where([c], c.ai_detection_status not in ["hard_rejected"])
    |> order_by([c], asc: c.inserted_at, asc: c.id)
    |> preload(:author)
    |> Repo.all()
  end

  def count_comments(commentable_type, commentable_id) do
    Comment
    |> where([c], c.commentable_type == ^commentable_type and c.commentable_id == ^commentable_id)
    |> where([c], is_nil(c.deleted_at))
    |> Repo.aggregate(:count)
  end

  def can_delete_comment?(user_id, comment, parent) do
    user_id == comment.author_id ||
      (parent.__struct__ == WallPost &&
         (user_id == parent.author_id || user_id == parent.wall_owner_id))
  end

  def soft_delete_comment(comment_id, user_id) do
    comment = Repo.get!(Comment, comment_id)

    # Get parent to check permissions
    can_delete =
      case comment.commentable_type do
        "wall_post" ->
          post = Repo.get!(WallPost, comment.commentable_id)
          can_delete_comment?(user_id, comment, post)

        _ ->
          user_id == comment.author_id
      end

    if can_delete do
      comment
      |> Ecto.Changeset.change(deleted_at: DateTime.utc_now() |> DateTime.truncate(:second))
      |> Repo.update()
    else
      {:error, :unauthorized}
    end
  end

  # === Likes (Polymorphic) ===

  def toggle_like(user_id, likeable_type, likeable_id) do
    case get_like(user_id, likeable_type, likeable_id) do
      nil ->
        %Like{}
        |> Like.changeset(%{
          user_id: user_id,
          likeable_type: likeable_type,
          likeable_id: likeable_id
        })
        |> Repo.insert()
        |> case do
          {:ok, like} -> {:ok, :liked, like}
          error -> error
        end

      like ->
        Repo.delete(like)
        {:ok, :unliked, nil}
    end
  end

  def get_like(user_id, likeable_type, likeable_id) do
    Like
    |> where(
      [l],
      l.user_id == ^user_id and l.likeable_type == ^likeable_type and
        l.likeable_id == ^likeable_id
    )
    |> Repo.one()
  end

  def liked?(user_id, likeable_type, likeable_id) do
    Repo.exists?(
      from l in Like,
        where:
          l.user_id == ^user_id and l.likeable_type == ^likeable_type and
            l.likeable_id == ^likeable_id
    )
  end

  def count_likes(likeable_type, likeable_id) do
    Like
    |> where([l], l.likeable_type == ^likeable_type and l.likeable_id == ^likeable_id)
    |> Repo.aggregate(:count)
  end

  def batch_like_counts(_likeable_type, ids) when ids == [], do: %{}

  def batch_like_counts(likeable_type, ids) do
    Like
    |> where([l], l.likeable_type == ^likeable_type and l.likeable_id in ^ids)
    |> group_by([l], l.likeable_id)
    |> select([l], {l.likeable_id, count(l.id)})
    |> Repo.all()
    |> Map.new()
  end

  def batch_comment_counts(_commentable_type, ids) when ids == [], do: %{}

  def batch_comment_counts(commentable_type, ids) do
    Comment
    |> where([c], c.commentable_type == ^commentable_type and c.commentable_id in ^ids)
    |> where([c], is_nil(c.deleted_at))
    |> group_by([c], c.commentable_id)
    |> select([c], {c.commentable_id, count(c.id)})
    |> Repo.all()
    |> Map.new()
  end

  def batch_liked_ids(_user_id, _likeable_type, ids) when ids == [], do: MapSet.new()

  def batch_liked_ids(user_id, likeable_type, ids) do
    Like
    |> where(
      [l],
      l.user_id == ^user_id and l.likeable_type == ^likeable_type and l.likeable_id in ^ids
    )
    |> select([l], l.likeable_id)
    |> Repo.all()
    |> MapSet.new()
  end

  # === Status Updates ===

  def create_status_update(attrs) do
    with :ok <- RateLimiter.check(attrs[:user_id] || attrs["user_id"], :create_status_update) do
      %StatusUpdate{}
      |> StatusUpdate.changeset(attrs)
      |> Repo.insert()
      |> case do
        {:ok, status} ->
          create_feed_item(%{
            user_id: status.user_id,
            item_type: "status_update",
            content_id: status.id
          })

          AIDetection.check_text(status.user_id, "status_update", status.id, status.body)

          # Fan out to friends' feeds
          friend_ids = Social.list_friends(status.user_id) |> Enum.map(& &1.id)

          for friend_id <- friend_ids do
            Phoenix.PubSub.broadcast(
              ParkBench.PubSub,
              "feed:#{friend_id}",
              {:new_feed_item, status.id}
            )
          end

          {:ok, status}

        error ->
          error
      end
    end
  end

  def get_latest_status(user_id) do
    StatusUpdate
    |> where([s], s.user_id == ^user_id)
    |> order_by([s], desc: s.inserted_at, desc: s.id)
    |> limit(1)
    |> Repo.one()
  end

  # === Feed Items ===

  def create_feed_item(attrs) do
    %FeedItem{}
    |> FeedItem.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Chronological news feed — fan-out-on-read from friends' feed_items"
  def get_news_feed(user_id, opts \\ []) do
    page = Keyword.get(opts, :page, 1)
    per_page = Keyword.get(opts, :per_page, 20)

    friend_ids = Social.list_friends(user_id) |> Enum.map(& &1.id)
    all_ids = [user_id | friend_ids]
    blocked_ids = blocked_user_ids(user_id)
    visible_ids = all_ids -- blocked_ids

    FeedItem
    |> where([fi], fi.user_id in type(^visible_ids, {:array, Ecto.UUID}))
    |> order_by([fi], desc: fi.inserted_at)
    |> offset(^((page - 1) * per_page))
    |> limit(^per_page)
    |> preload(:user)
    |> Repo.all()
    |> load_feed_content()
  end

  defp load_feed_content(feed_items) do
    # Group content IDs by type
    wall_post_ids = for %{item_type: "wall_post", content_id: id} <- feed_items, do: id
    status_ids = for %{item_type: "status_update", content_id: id} <- feed_items, do: id
    friend_ids = for %{item_type: "new_friendship", content_id: id} <- feed_items, do: id

    profile_photo_ids =
      for %{item_type: "profile_photo_updated", content_id: id} <- feed_items, do: id

    profile_updated_ids =
      for %{item_type: "profile_updated", content_id: id} <- feed_items, do: id

    # Batch load each type
    wall_posts = batch_load_wall_posts(wall_post_ids)
    statuses = batch_load_statuses(status_ids)
    friends = batch_load_users(friend_ids)
    profile_photos = batch_load_profile_photos(profile_photo_ids)
    profile_updated_users = batch_load_users(profile_updated_ids)

    feed_items
    |> Enum.map(fn item ->
      content =
        case item.item_type do
          "wall_post" -> Map.get(wall_posts, item.content_id)
          "status_update" -> Map.get(statuses, item.content_id)
          "new_friendship" -> Map.get(friends, item.content_id)
          "profile_photo_updated" -> Map.get(profile_photos, item.content_id)
          "profile_updated" -> Map.get(profile_updated_users, item.content_id)
          _ -> nil
        end

      %{feed_item: item, content: content}
    end)
    |> Enum.filter(fn %{content: c} -> c != nil end)
  end

  defp batch_load_wall_posts([]), do: %{}

  defp batch_load_wall_posts(ids) do
    WallPost
    |> where([p], p.id in ^ids and is_nil(p.deleted_at))
    |> where([p], p.ai_detection_status not in ["hard_rejected"])
    |> preload([:author, :wall_owner])
    |> Repo.all()
    |> Map.new(&{&1.id, &1})
  end

  defp batch_load_statuses([]), do: %{}

  defp batch_load_statuses(ids) do
    StatusUpdate
    |> where([s], s.id in ^ids)
    |> Repo.all()
    |> Map.new(&{&1.id, &1})
  end

  defp batch_load_users([]), do: %{}

  defp batch_load_users(ids) do
    ParkBench.Accounts.User
    |> where([u], u.id in ^ids)
    |> Repo.all()
    |> Map.new(&{&1.id, &1})
  end

  defp batch_load_profile_photos([]), do: %{}

  defp batch_load_profile_photos(ids) do
    ParkBench.Accounts.ProfilePhoto
    |> where([p], p.id in ^ids)
    |> preload(:user)
    |> Repo.all()
    |> Map.new(&{&1.id, &1})
  end

  def count_new_feed_items_since(user_id, since) do
    friend_ids = Social.list_friends(user_id) |> Enum.map(& &1.id)
    all_ids = [user_id | friend_ids]

    FeedItem
    |> where([fi], fi.user_id in type(^all_ids, {:array, Ecto.UUID}))
    |> where([fi], fi.inserted_at > ^since)
    |> Repo.aggregate(:count)
  end

  # === Helpers ===

  defp blocked_user_ids(user_id) do
    blocker_ids =
      from(b in Block, where: b.blocked_id == ^user_id, select: b.blocker_id) |> Repo.all()

    blocked_ids =
      from(b in Block, where: b.blocker_id == ^user_id, select: b.blocked_id) |> Repo.all()

    Enum.uniq(blocker_ids ++ blocked_ids)
  end

  # === Soft Delete Cleanup (called by Oban worker) ===

  def hard_delete_old_soft_deletes(days_ago \\ 30) do
    cutoff = DateTime.add(DateTime.utc_now(), -days_ago * 86400, :second)

    {post_count, _} =
      from(p in WallPost, where: not is_nil(p.deleted_at) and p.deleted_at < ^cutoff)
      |> Repo.delete_all()

    {comment_count, _} =
      from(c in Comment, where: not is_nil(c.deleted_at) and c.deleted_at < ^cutoff)
      |> Repo.delete_all()

    {:ok, %{posts: post_count, comments: comment_count}}
  end
end
