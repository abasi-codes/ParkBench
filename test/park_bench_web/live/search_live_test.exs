defmodule ParkBenchWeb.SearchLiveTest do
  use ParkBenchWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "unauthenticated" do
    test "redirects unauthenticated users", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/search")
    end
  end

  describe "authenticated" do
    setup %{conn: conn} do
      register_and_log_in_user(%{conn: conn})
    end

    test "renders search page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/search")
      assert html =~ "Search"
      assert html =~ "Search for people"
    end

    test "returns results for valid query", %{conn: conn} do
      # Create a user to search for
      _searchable_user =
        insert(:user,
          display_name: "Searchable Person",
          email_verified_at: DateTime.utc_now() |> DateTime.truncate(:second)
        )

      {:ok, view, _html} = live(conn, ~p"/search")

      html =
        view
        |> form("form[phx-submit='search']", %{q: "Searchable"})
        |> render_submit()

      assert html =~ "Searchable Person"
      assert html =~ ~s|Results for|
    end

    test "shows no results message for empty results", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/search")

      html =
        view
        |> form("form[phx-submit='search']", %{q: "zzzznonexistentuserzzz"})
        |> render_submit()

      assert html =~ "No results found"
    end

    test "shows Add Friend button for non-friends in results", %{conn: conn} do
      insert(:user,
        display_name: "Findable User",
        email_verified_at: DateTime.utc_now() |> DateTime.truncate(:second)
      )

      {:ok, view, _html} = live(conn, ~p"/search")

      html =
        view
        |> form("form[phx-submit='search']", %{q: "Findable"})
        |> render_submit()

      assert html =~ "Add Friend"
    end

    test "shows Friends badge for existing friends in results", %{conn: conn, user: user} do
      friend =
        insert(:user,
          display_name: "Already Friend",
          email_verified_at: DateTime.utc_now() |> DateTime.truncate(:second)
        )

      # Create friendship
      {low_id, high_id} =
        if user.id < friend.id, do: {user.id, friend.id}, else: {friend.id, user.id}

      low_user = ParkBench.Accounts.get_user!(low_id)
      high_user = ParkBench.Accounts.get_user!(high_id)
      insert(:friendship, user: low_user, friend: high_user)

      {:ok, view, _html} = live(conn, ~p"/search")

      html =
        view
        |> form("form[phx-submit='search']", %{q: "Already Friend"})
        |> render_submit()

      assert html =~ "Already Friend"
      # Should show "Friends" button instead of "Add Friend"
      assert html =~ ">Friends<"
    end
  end
end
