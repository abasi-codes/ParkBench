defmodule SunporchWeb.FeedLiveTest do
  use SunporchWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "unauthenticated" do
    test "redirects unauthenticated users to /", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/feed")
    end
  end

  describe "authenticated" do
    setup %{conn: conn} do
      register_and_log_in_user(%{conn: conn})
    end

    test "renders feed page for authenticated user", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/feed")
      assert html =~ "News Feed"
      assert html =~ "What&#39;s on your mind?"
      assert html =~ "submit_post"
      assert html =~ "update_status"
    end

    test "shows empty feed message when no friends", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/feed")
      assert html =~ "Welcome to Sunporch!"
      assert html =~ "Your news feed is empty"
      assert html =~ "Find Friends"
    end

    test "can create a status update", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/feed")

      html =
        view
        |> form("form[phx-submit='update_status']", %{body: "feeling great"})
        |> render_submit()

      assert html =~ "feeling great"
      assert html =~ user.display_name
    end

    test "can create a wall post on own wall", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/feed")

      view
      |> form("form[phx-submit='submit_post']", %{body: "Hello world, this is my first post!"})
      |> render_submit()

      # The feed is re-fetched after posting. We verify no error flash.
      refute render(view) =~ "Could not create post"
    end

    test "shows friends' posts in feed", %{conn: conn, user: user} do
      friend =
        insert(:user, email_verified_at: DateTime.utc_now() |> DateTime.truncate(:second))

      # Create friendship (canonical ordering)
      {low_id, high_id} =
        if user.id < friend.id, do: {user.id, friend.id}, else: {friend.id, user.id}

      low_user = Sunporch.Accounts.get_user!(low_id)
      high_user = Sunporch.Accounts.get_user!(high_id)
      insert(:friendship, user: low_user, friend: high_user)

      # Create a wall post by the friend
      {:ok, _post} =
        Sunporch.Timeline.create_wall_post(%{
          author_id: friend.id,
          wall_owner_id: friend.id,
          body: "Friend's wall post content here"
        })

      {:ok, _view, html} = live(conn, ~p"/feed")
      # With a friend, the feed should no longer show the empty message
      refute html =~ "Your news feed is empty"
    end

    test "shows search link on feed page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/feed")
      assert html =~ ~s|href="/search"|
    end

    test "shows profile photo update card in feed", %{conn: conn, user: user} do
      friend =
        insert(:user, email_verified_at: DateTime.utc_now() |> DateTime.truncate(:second))

      {low_id, high_id} =
        if user.id < friend.id, do: {user.id, friend.id}, else: {friend.id, user.id}

      low_user = Sunporch.Accounts.get_user!(low_id)
      high_user = Sunporch.Accounts.get_user!(high_id)
      insert(:friendship, user: low_user, friend: high_user)

      {:ok, _photo} =
        Sunporch.Accounts.create_profile_photo(friend.id, %{
          original_url: "https://example.com/friend-pic.jpg"
        })

      {:ok, _view, html} = live(conn, ~p"/feed")
      assert html =~ "updated their profile picture."
      assert html =~ "friend-pic.jpg"
    end

    test "shows cover photo update card in feed", %{conn: conn, user: user} do
      friend =
        insert(:user, email_verified_at: DateTime.utc_now() |> DateTime.truncate(:second))

      {low_id, high_id} =
        if user.id < friend.id, do: {user.id, friend.id}, else: {friend.id, user.id}

      low_user = Sunporch.Accounts.get_user!(low_id)
      high_user = Sunporch.Accounts.get_user!(high_id)
      insert(:friendship, user: low_user, friend: high_user)

      {:ok, _profile} =
        Sunporch.Accounts.update_cover_photo(friend.id, "https://example.com/cover.jpg")

      {:ok, _view, html} = live(conn, ~p"/feed")
      assert html =~ "updated their cover photo."
    end
  end
end
