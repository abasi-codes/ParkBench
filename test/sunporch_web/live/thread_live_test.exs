defmodule SunporchWeb.ThreadLiveTest do
  use SunporchWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "unauthenticated" do
    test "redirects unauthenticated users to /", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/inbox/thread/#{Ecto.UUID.generate()}")
    end
  end

  describe "authenticated" do
    setup %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      friend = insert(:user, email_verified_at: DateTime.utc_now() |> DateTime.truncate(:second))

      # Create friendship
      {low_id, high_id} = if user.id < friend.id, do: {user.id, friend.id}, else: {friend.id, user.id}
      low_user = Sunporch.Accounts.get_user!(low_id)
      high_user = Sunporch.Accounts.get_user!(high_id)
      insert(:friendship, user: low_user, friend: high_user)

      # Create thread
      {:ok, %{thread: thread}} = Sunporch.Messaging.create_thread(user.id, friend.id, "Test Subject", "Hello friend!")

      %{conn: conn, user: user, friend: friend, thread: thread}
    end

    test "renders thread with messages", %{conn: conn, thread: thread, user: user} do
      {:ok, _view, html} = live(conn, ~p"/inbox/thread/#{thread.id}")
      assert html =~ "Test Subject"
      assert html =~ user.display_name
    end

    test "can send a reply", %{conn: conn, thread: thread} do
      {:ok, view, _html} = live(conn, ~p"/inbox/thread/#{thread.id}")

      view
      |> form("form[phx-submit='send_reply']", %{body: "This is my reply!"})
      |> render_submit()

      html = render(view)
      assert html =~ "This is my reply!"
    end

    test "redirects on invalid thread", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/inbox"}}} = live(conn, ~p"/inbox/thread/#{Ecto.UUID.generate()}")
    end
  end
end
