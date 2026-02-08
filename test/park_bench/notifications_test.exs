defmodule ParkBench.NotificationsTest do
  use ParkBench.DataCase, async: true

  alias ParkBench.Notifications

  # ──────────────────────────────────────────────
  # create_notification/1
  # ──────────────────────────────────────────────

  describe "create_notification/1" do
    test "creates a notification with valid attributes" do
      user = insert(:user)
      actor = insert(:user)

      assert {:ok, notification} =
               Notifications.create_notification(%{
                 user_id: user.id,
                 actor_id: actor.id,
                 type: "friend_request",
                 target_type: "user",
                 target_id: actor.id
               })

      assert notification.user_id == user.id
      assert notification.actor_id == actor.id
      assert notification.type == "friend_request"
      assert notification.read_at == nil
    end

    test "raises for invalid notification type" do
      user = insert(:user)
      actor = insert(:user)

      assert_raise ArgumentError, ~r/Invalid notification type/, fn ->
        Notifications.create_notification(%{
          user_id: user.id,
          actor_id: actor.id,
          type: "invalid_type",
          target_type: "user",
          target_id: actor.id
        })
      end
    end

    test "returns error for self-notification (user_id == actor_id)" do
      user = insert(:user)

      # The type check passes, but the changeset validation for self-notification fails
      assert {:error, changeset} =
               Notifications.create_notification(%{
                 user_id: user.id,
                 actor_id: user.id,
                 type: "friend_request",
                 target_type: "user",
                 target_id: user.id
               })

      assert errors_on(changeset).actor_id != []
    end
  end

  # ──────────────────────────────────────────────
  # list_notifications/2
  # ──────────────────────────────────────────────

  describe "list_notifications/2" do
    test "returns notifications with unread first" do
      user = insert(:user)
      actor = insert(:user)

      {:ok, read_notif} =
        Notifications.create_notification(%{
          user_id: user.id,
          actor_id: actor.id,
          type: "friend_request",
          target_type: "user",
          target_id: actor.id
        })

      Notifications.mark_read(read_notif.id, user.id)

      {:ok, _unread_notif} =
        Notifications.create_notification(%{
          user_id: user.id,
          actor_id: actor.id,
          type: "poke",
          target_type: "user",
          target_id: actor.id
        })

      notifications = Notifications.list_notifications(user.id)
      assert length(notifications) == 2

      # Unread should come first
      assert hd(notifications).read_at == nil
    end

    test "paginates results" do
      user = insert(:user)
      actor = insert(:user)

      for _i <- 1..5 do
        Notifications.create_notification(%{
          user_id: user.id,
          actor_id: actor.id,
          type: "poke",
          target_type: "user",
          target_id: actor.id
        })
      end

      page1 = Notifications.list_notifications(user.id, page: 1, per_page: 3)
      page2 = Notifications.list_notifications(user.id, page: 2, per_page: 3)

      assert length(page1) == 3
      assert length(page2) == 2
    end
  end

  # ──────────────────────────────────────────────
  # count_unread/1
  # ──────────────────────────────────────────────

  describe "count_unread/1" do
    test "counts unread notifications" do
      user = insert(:user)
      actor = insert(:user)

      {:ok, _} =
        Notifications.create_notification(%{
          user_id: user.id,
          actor_id: actor.id,
          type: "friend_request",
          target_type: "user",
          target_id: actor.id
        })

      {:ok, _} =
        Notifications.create_notification(%{
          user_id: user.id,
          actor_id: actor.id,
          type: "poke",
          target_type: "user",
          target_id: actor.id
        })

      assert Notifications.count_unread(user.id) == 2
    end

    test "returns 0 when all read" do
      user = insert(:user)
      actor = insert(:user)

      {:ok, notif} =
        Notifications.create_notification(%{
          user_id: user.id,
          actor_id: actor.id,
          type: "friend_request",
          target_type: "user",
          target_id: actor.id
        })

      Notifications.mark_read(notif.id, user.id)
      assert Notifications.count_unread(user.id) == 0
    end
  end

  # ──────────────────────────────────────────────
  # mark_read/2
  # ──────────────────────────────────────────────

  describe "mark_read/2" do
    test "marks a notification as read" do
      user = insert(:user)
      actor = insert(:user)

      {:ok, notif} =
        Notifications.create_notification(%{
          user_id: user.id,
          actor_id: actor.id,
          type: "friend_request",
          target_type: "user",
          target_id: actor.id
        })

      assert {:ok, marked} = Notifications.mark_read(notif.id, user.id)
      assert marked.read_at != nil
    end

    test "returns error when another user tries to mark" do
      user = insert(:user)
      actor = insert(:user)
      other = insert(:user)

      {:ok, notif} =
        Notifications.create_notification(%{
          user_id: user.id,
          actor_id: actor.id,
          type: "friend_request",
          target_type: "user",
          target_id: actor.id
        })

      assert {:error, :unauthorized} = Notifications.mark_read(notif.id, other.id)
    end
  end

  # ──────────────────────────────────────────────
  # mark_all_read/1
  # ──────────────────────────────────────────────

  describe "mark_all_read/1" do
    test "marks all notifications as read" do
      user = insert(:user)
      actor = insert(:user)

      for _ <- 1..3 do
        Notifications.create_notification(%{
          user_id: user.id,
          actor_id: actor.id,
          type: "poke",
          target_type: "user",
          target_id: actor.id
        })
      end

      assert Notifications.count_unread(user.id) == 3

      Notifications.mark_all_read(user.id)

      assert Notifications.count_unread(user.id) == 0
    end
  end

  # ──────────────────────────────────────────────
  # prune_old_notifications/0
  # ──────────────────────────────────────────────

  describe "prune_old_notifications/0" do
    test "prunes old read notifications (>30 days) and very old unread (>90 days)" do
      user = insert(:user)
      actor = insert(:user)

      # Create an old read notification (> 30 days)
      {:ok, old_read} =
        Notifications.create_notification(%{
          user_id: user.id,
          actor_id: actor.id,
          type: "friend_request",
          target_type: "user",
          target_id: actor.id
        })

      Notifications.mark_read(old_read.id, user.id)

      # Backdate to 35 days ago
      old_read
      |> Ecto.Changeset.change(
        inserted_at:
          DateTime.utc_now()
          |> DateTime.add(-35 * 86400, :second)
          |> DateTime.truncate(:second)
      )
      |> Repo.update!()

      # Create a very old unread notification (> 90 days)
      {:ok, very_old} =
        Notifications.create_notification(%{
          user_id: user.id,
          actor_id: actor.id,
          type: "poke",
          target_type: "user",
          target_id: actor.id
        })

      very_old
      |> Ecto.Changeset.change(
        inserted_at:
          DateTime.utc_now()
          |> DateTime.add(-95 * 86400, :second)
          |> DateTime.truncate(:second)
      )
      |> Repo.update!()

      assert {:ok, %{read_pruned: read_count, old_pruned: old_count}} =
               Notifications.prune_old_notifications()

      assert read_count >= 1
      assert old_count >= 1
    end

    test "does not prune recent notifications" do
      user = insert(:user)
      actor = insert(:user)

      {:ok, _} =
        Notifications.create_notification(%{
          user_id: user.id,
          actor_id: actor.id,
          type: "friend_request",
          target_type: "user",
          target_id: actor.id
        })

      assert {:ok, %{read_pruned: 0, old_pruned: 0}} = Notifications.prune_old_notifications()
    end
  end

  # ──────────────────────────────────────────────
  # Helper Functions
  # ──────────────────────────────────────────────

  describe "notify_friend_request/2" do
    test "creates a friend_request notification" do
      sender = insert(:user)
      receiver = insert(:user)

      assert {:ok, notif} = Notifications.notify_friend_request(sender, receiver.id)
      assert notif.type == "friend_request"
      assert notif.user_id == receiver.id
      assert notif.actor_id == sender.id
    end
  end

  describe "notify_friend_accept/2" do
    test "creates a friend_accept notification" do
      accepter = insert(:user)
      requester = insert(:user)

      assert {:ok, notif} = Notifications.notify_friend_accept(accepter, requester.id)
      assert notif.type == "friend_accept"
      assert notif.user_id == requester.id
      assert notif.actor_id == accepter.id
    end
  end

  describe "notify_wall_post/1" do
    test "creates notification for wall post when author differs from owner" do
      author = insert(:user)
      owner = insert(:user)

      post = %{
        author_id: author.id,
        wall_owner_id: owner.id,
        id: Ecto.UUID.generate()
      }

      assert {:ok, notif} = Notifications.notify_wall_post(post)
      assert notif.type == "wall_post"
      assert notif.user_id == owner.id
      assert notif.actor_id == author.id
    end

    test "does not create notification when author is the wall owner" do
      user = insert(:user)

      post = %{
        author_id: user.id,
        wall_owner_id: user.id,
        id: Ecto.UUID.generate()
      }

      assert Notifications.notify_wall_post(post) == nil
    end
  end

  describe "notify_comment/2" do
    test "creates notification for comment when author differs from parent author" do
      commenter = insert(:user)
      parent_author = insert(:user)

      comment = %{
        author_id: commenter.id,
        commentable_type: "wall_post",
        commentable_id: Ecto.UUID.generate()
      }

      assert {:ok, notif} = Notifications.notify_comment(comment, parent_author.id)
      assert notif.type == "post_comment"
    end

    test "does not create notification when comment author is parent author" do
      user = insert(:user)

      comment = %{
        author_id: user.id,
        commentable_type: "wall_post",
        commentable_id: Ecto.UUID.generate()
      }

      assert Notifications.notify_comment(comment, user.id) == nil
    end
  end

  describe "notify_poke/2" do
    test "creates a poke notification" do
      poker = insert(:user)
      pokee = insert(:user)

      assert {:ok, notif} = Notifications.notify_poke(poker, pokee.id)
      assert notif.type == "poke"
      assert notif.user_id == pokee.id
      assert notif.actor_id == poker.id
    end
  end

  describe "notify_new_message/3" do
    test "creates a new_message notification" do
      sender = insert(:user)
      recipient = insert(:user)
      thread_id = Ecto.UUID.generate()

      assert {:ok, notif} = Notifications.notify_new_message(sender, recipient.id, thread_id)
      assert notif.type == "new_message"
      assert notif.user_id == recipient.id
      assert notif.target_id == thread_id
    end
  end
end
