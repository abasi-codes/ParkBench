defmodule ParkBenchWeb.FriendRequestsLiveTest do
  use ParkBenchWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "unauthenticated" do
    test "redirects unauthenticated users", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/friends/requests")
    end
  end

  describe "authenticated" do
    setup %{conn: conn} do
      register_and_log_in_user(%{conn: conn})
    end

    test "renders friend requests page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/friends/requests")
      assert html =~ "Friend Requests"
    end

    test "shows no pending requests message when empty", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/friends/requests")
      assert html =~ "No pending friend requests"
    end

    test "shows pending received requests", %{conn: conn, user: user} do
      sender =
        insert(:user,
          display_name: "Request Sender",
          email_verified_at: DateTime.utc_now() |> DateTime.truncate(:second)
        )

      {:ok, _request} = ParkBench.Social.send_friend_request(sender.id, user.id)

      {:ok, _view, html} = live(conn, ~p"/friends/requests")
      assert html =~ "Request Sender"
      assert html =~ "Confirm"
      assert html =~ "Ignore"
    end

    test "can accept a friend request", %{conn: conn, user: user} do
      sender =
        insert(:user,
          display_name: "Acceptable Sender",
          email_verified_at: DateTime.utc_now() |> DateTime.truncate(:second)
        )

      {:ok, request} = ParkBench.Social.send_friend_request(sender.id, user.id)

      {:ok, view, _html} = live(conn, ~p"/friends/requests")

      html = render_click(view, "accept", %{"id" => request.id})

      # After accepting, the request should be gone from pending
      refute html =~ "Acceptable Sender"
      assert html =~ "No pending friend requests"

      # Verify they are now friends
      assert ParkBench.Social.friends?(user.id, sender.id)
    end

    test "can reject a friend request", %{conn: conn, user: user} do
      sender =
        insert(:user,
          display_name: "Rejectable Sender",
          email_verified_at: DateTime.utc_now() |> DateTime.truncate(:second)
        )

      {:ok, request} = ParkBench.Social.send_friend_request(sender.id, user.id)

      {:ok, view, _html} = live(conn, ~p"/friends/requests")

      html = render_click(view, "reject", %{"id" => request.id})

      # After rejecting, the request should be gone
      refute html =~ "Rejectable Sender"

      # Verify they are NOT friends
      refute ParkBench.Social.friends?(user.id, sender.id)
    end

    test "shows sent requests", %{conn: conn, user: user} do
      receiver =
        insert(:user,
          display_name: "Pending Receiver",
          email_verified_at: DateTime.utc_now() |> DateTime.truncate(:second)
        )

      {:ok, _request} = ParkBench.Social.send_friend_request(user.id, receiver.id)

      {:ok, _view, html} = live(conn, ~p"/friends/requests")
      assert html =~ "Sent Requests"
      assert html =~ "Pending Receiver"
      assert html =~ "Cancel"
    end

    test "can cancel a sent request", %{conn: conn, user: user} do
      receiver =
        insert(:user,
          display_name: "Cancelable Receiver",
          email_verified_at: DateTime.utc_now() |> DateTime.truncate(:second)
        )

      {:ok, request} = ParkBench.Social.send_friend_request(user.id, receiver.id)

      {:ok, view, _html} = live(conn, ~p"/friends/requests")

      html = render_click(view, "cancel", %{"id" => request.id})

      refute html =~ "Cancelable Receiver"
    end
  end
end
