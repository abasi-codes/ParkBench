defmodule ParkBench.Notifications do
  @moduledoc "Notification system — 8 types with badge counts and real-time updates"

  import Ecto.Query
  alias ParkBench.Repo
  alias ParkBench.Notifications.Notification

  @notification_types ~w(friend_request friend_accept wall_post wall_comment post_comment new_message poke photo_tag)

  def create_notification(attrs) do
    type = Map.get(attrs, :type) || Map.get(attrs, "type")

    unless type in @notification_types do
      raise ArgumentError, "Invalid notification type: #{inspect(type)}"
    end

    %Notification{}
    |> Notification.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, notification} ->
        Phoenix.PubSub.broadcast(
          ParkBench.PubSub,
          "user:#{notification.user_id}",
          {:new_notification, notification}
        )

        {:ok, notification}

      error ->
        error
    end
  end

  def list_notifications(user_id, opts \\ []) do
    page = Keyword.get(opts, :page, 1)
    per_page = Keyword.get(opts, :per_page, 20)

    Notification
    |> where([n], n.user_id == ^user_id)
    |> order_by([n],
      asc: fragment("CASE WHEN ? IS NULL THEN 0 ELSE 1 END", n.read_at),
      desc: n.inserted_at
    )
    |> offset(^((page - 1) * per_page))
    |> limit(^per_page)
    |> preload(:actor)
    |> Repo.all()
  end

  def count_unread(user_id) do
    Notification
    |> where([n], n.user_id == ^user_id and is_nil(n.read_at))
    |> Repo.aggregate(:count)
  end

  def mark_read(notification_id, user_id) do
    notification = Repo.get!(Notification, notification_id)

    if notification.user_id != user_id do
      {:error, :unauthorized}
    else
      notification
      |> Ecto.Changeset.change(read_at: DateTime.utc_now() |> DateTime.truncate(:second))
      |> Repo.update()
    end
  end

  def mark_all_read(user_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    from(n in Notification,
      where: n.user_id == ^user_id and is_nil(n.read_at)
    )
    |> Repo.update_all(set: [read_at: now])
  end

  @doc "Prune old notifications — called by Oban cron worker"
  def prune_old_notifications do
    now = DateTime.utc_now()
    read_cutoff = DateTime.add(now, -30 * 86400, :second)
    all_cutoff = DateTime.add(now, -90 * 86400, :second)

    {read_count, _} =
      from(n in Notification,
        where: not is_nil(n.read_at) and n.inserted_at < ^read_cutoff
      )
      |> Repo.delete_all()

    {all_count, _} =
      from(n in Notification,
        where: n.inserted_at < ^all_cutoff
      )
      |> Repo.delete_all()

    {:ok, %{read_pruned: read_count, old_pruned: all_count}}
  end

  # === Notification helpers for common actions ===

  def notify_friend_request(sender, receiver_id) do
    create_notification(%{
      user_id: receiver_id,
      actor_id: sender.id,
      type: "friend_request",
      target_type: "user",
      target_id: sender.id
    })
  end

  def notify_friend_accept(accepter, requester_id) do
    create_notification(%{
      user_id: requester_id,
      actor_id: accepter.id,
      type: "friend_accept",
      target_type: "user",
      target_id: accepter.id
    })
  end

  def notify_wall_post(post) do
    if post.author_id != post.wall_owner_id do
      create_notification(%{
        user_id: post.wall_owner_id,
        actor_id: post.author_id,
        type: "wall_post",
        target_type: "wall_post",
        target_id: post.id
      })
    end
  end

  def notify_comment(comment, parent_author_id) do
    if comment.author_id != parent_author_id do
      create_notification(%{
        user_id: parent_author_id,
        actor_id: comment.author_id,
        type: "post_comment",
        target_type: comment.commentable_type,
        target_id: comment.commentable_id
      })
    end
  end

  def notify_poke(poker, pokee_id) do
    create_notification(%{
      user_id: pokee_id,
      actor_id: poker.id,
      type: "poke",
      target_type: "user",
      target_id: poker.id
    })
  end

  def notify_new_message(sender, recipient_id, thread_id) do
    create_notification(%{
      user_id: recipient_id,
      actor_id: sender.id,
      type: "new_message",
      target_type: "message_thread",
      target_id: thread_id
    })
  end
end
