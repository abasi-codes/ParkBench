defmodule ParkBenchWeb.RealtimeBadgesTest do
  use ParkBenchWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "real-time header badges" do
    setup %{conn: conn} do
      register_and_log_in_user(%{conn: conn})
    end

    test "notification count increments on broadcast", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/feed")

      # Initial count should be 0
      assert get_assign(view, :unread_notifications) == 0

      Phoenix.PubSub.broadcast(ParkBench.PubSub, "user:#{user.id}", {:new_notification, %{}})
      # Let the message be processed
      _ = render(view)

      assert get_assign(view, :unread_notifications) == 1
    end

    test "message count increments on broadcast", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/feed")

      assert get_assign(view, :unread_messages) == 0

      Phoenix.PubSub.broadcast(ParkBench.PubSub, "user:#{user.id}", {:new_message, "thread123"})
      _ = render(view)

      assert get_assign(view, :unread_messages) == 1
    end

    test "friend request count increments on broadcast", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/feed")

      assert get_assign(view, :pending_friend_requests) == 0

      Phoenix.PubSub.broadcast(ParkBench.PubSub, "user:#{user.id}", {:friend_request, %{}})
      _ = render(view)

      assert get_assign(view, :pending_friend_requests) == 1
    end

    test "friend request count decrements on accepted broadcast", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/feed")

      # Increment first
      Phoenix.PubSub.broadcast(ParkBench.PubSub, "user:#{user.id}", {:friend_request, %{}})
      _ = render(view)
      assert get_assign(view, :pending_friend_requests) == 1

      # Then decrement
      Phoenix.PubSub.broadcast(ParkBench.PubSub, "user:#{user.id}", {:friend_accepted, %{}})
      _ = render(view)
      assert get_assign(view, :pending_friend_requests) == 0
    end

    test "friend request count does not go below zero", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/feed")

      Phoenix.PubSub.broadcast(ParkBench.PubSub, "user:#{user.id}", {:friend_accepted, %{}})
      _ = render(view)
      assert get_assign(view, :pending_friend_requests) == 0
    end

    test "pokes update on broadcast", %{conn: conn, user: user} do
      poker = insert(:user)
      insert(:poke, poker: poker, pokee: user)

      {:ok, view, _html} = live(conn, ~p"/feed")

      Phoenix.PubSub.broadcast(ParkBench.PubSub, "user:#{user.id}", {:poked, %{}})
      _ = render(view)

      pokes = get_assign(view, :pending_pokes)
      assert length(pokes) > 0
    end

    test "works across different pages", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/notifications")

      Phoenix.PubSub.broadcast(ParkBench.PubSub, "user:#{user.id}", {:new_notification, %{}})
      _ = render(view)

      assert get_assign(view, :unread_notifications) == 1
    end

    test "unknown messages don't crash", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/feed")

      Phoenix.PubSub.broadcast(ParkBench.PubSub, "user:#{user.id}", {:unknown_event, %{}})

      # Should still be alive and rendering
      assert render(view) =~ "Welcome to ParkBench"
    end
  end

  defp get_assign(view, key) do
    :sys.get_state(view.pid).socket.assigns[key]
  end
end
