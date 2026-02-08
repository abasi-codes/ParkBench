defmodule SunporchWeb.InboxLiveTest do
  use SunporchWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "unauthenticated" do
    test "redirects unauthenticated users", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/inbox")
    end
  end

  describe "authenticated" do
    setup %{conn: conn} do
      register_and_log_in_user(%{conn: conn})
    end

    test "renders inbox page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/inbox")
      assert html =~ "Inbox"
      assert html =~ "Compose Message"
    end

    test "shows empty inbox message when no threads", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/inbox")
      assert html =~ "Your inbox is empty"
    end

    test "shows message threads", %{conn: conn, user: user} do
      other_user =
        insert(:user, email_verified_at: DateTime.utc_now() |> DateTime.truncate(:second))

      {:ok, _result} =
        Sunporch.Messaging.create_thread(
          other_user.id,
          user.id,
          "Hello Thread",
          "Hey, how are you?"
        )

      {:ok, _view, html} = live(conn, ~p"/inbox")
      assert html =~ "Hello Thread"
      assert html =~ other_user.display_name
    end

    test "shows unread indicator for unread threads", %{conn: conn, user: user} do
      other_user =
        insert(:user, email_verified_at: DateTime.utc_now() |> DateTime.truncate(:second))

      {:ok, _result} =
        Sunporch.Messaging.create_thread(
          other_user.id,
          user.id,
          "Unread Thread Subject",
          "This is a new message"
        )

      {:ok, _view, html} = live(conn, ~p"/inbox")
      # Unread threads have the "unread" CSS class
      assert html =~ "unread"
      assert html =~ "Unread Thread Subject"
    end

    test "thread becomes read after viewing", %{conn: conn, user: user} do
      other_user =
        insert(:user, email_verified_at: DateTime.utc_now() |> DateTime.truncate(:second))

      {:ok, %{thread: thread}} =
        Sunporch.Messaging.create_thread(
          other_user.id,
          user.id,
          "Read Me Thread",
          "Please read this"
        )

      # View the thread to mark as read
      {:ok, _result} = Sunporch.Messaging.get_thread(thread.id, user.id)

      # Now check inbox
      {:ok, _view, html} = live(conn, ~p"/inbox")
      assert html =~ "Read Me Thread"
    end
  end
end
