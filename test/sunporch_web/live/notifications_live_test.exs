defmodule SunporchWeb.NotificationsLiveTest do
  use SunporchWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "unauthenticated" do
    test "redirects unauthenticated users", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/notifications")
    end
  end

  describe "authenticated" do
    setup %{conn: conn} do
      register_and_log_in_user(%{conn: conn})
    end

    test "renders notifications page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/notifications")
      assert html =~ "Notifications"
      assert html =~ "Mark All as Read"
    end

    test "shows empty notifications message", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/notifications")
      assert html =~ "All caught up"
    end

    test "shows notifications", %{conn: conn, user: user} do
      actor =
        insert(:user, email_verified_at: DateTime.utc_now() |> DateTime.truncate(:second))

      {:ok, _notif} =
        Sunporch.Notifications.create_notification(%{
          user_id: user.id,
          actor_id: actor.id,
          type: "friend_request",
          target_type: "user",
          target_id: actor.id
        })

      {:ok, _view, html} = live(conn, ~p"/notifications")
      assert html =~ actor.display_name
      assert html =~ "sent you a friend request"
    end

    test "can mark a notification as read", %{conn: conn, user: user} do
      actor =
        insert(:user, email_verified_at: DateTime.utc_now() |> DateTime.truncate(:second))

      {:ok, notif} =
        Sunporch.Notifications.create_notification(%{
          user_id: user.id,
          actor_id: actor.id,
          type: "wall_post",
          target_type: "wall_post",
          target_id: Ecto.UUID.generate()
        })

      {:ok, view, html} = live(conn, ~p"/notifications")
      # Notification is unread (has "unread" class)
      assert html =~ "unread"

      # Click to mark as read
      html = render_click(view, "mark_read", %{"id" => notif.id})
      # After marking read, the unread class should be gone for that notification
      refute html =~ "unread"
    end

    test "can mark all notifications as read", %{conn: conn, user: user} do
      actor =
        insert(:user, email_verified_at: DateTime.utc_now() |> DateTime.truncate(:second))

      for type <- ["friend_request", "wall_post", "poke"] do
        Sunporch.Notifications.create_notification(%{
          user_id: user.id,
          actor_id: actor.id,
          type: type,
          target_type: "user",
          target_id: actor.id
        })
      end

      {:ok, view, html} = live(conn, ~p"/notifications")
      assert html =~ "unread"

      html = render_click(view, "mark_all_read")
      refute html =~ "unread"
    end

    test "shows different notification types correctly", %{conn: conn, user: user} do
      actor =
        insert(:user, email_verified_at: DateTime.utc_now() |> DateTime.truncate(:second))

      Sunporch.Notifications.create_notification(%{
        user_id: user.id,
        actor_id: actor.id,
        type: "poke",
        target_type: "user",
        target_id: actor.id
      })

      {:ok, _view, html} = live(conn, ~p"/notifications")
      assert html =~ "poked you"
    end
  end
end
