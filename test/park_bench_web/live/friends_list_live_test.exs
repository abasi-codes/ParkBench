defmodule ParkBenchWeb.FriendsListLiveTest do
  use ParkBenchWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "unauthenticated" do
    test "redirects unauthenticated users to /", %{conn: conn} do
      user = insert(:user, email_verified_at: DateTime.utc_now() |> DateTime.truncate(:second))
      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/profile/#{user.slug}/friends")
    end
  end

  describe "authenticated" do
    setup %{conn: conn} do
      register_and_log_in_user(%{conn: conn})
    end

    test "renders friends list page for a user", %{conn: conn, user: user} do
      {:ok, _view, html} = live(conn, ~p"/profile/#{user.slug}/friends")
      assert html =~ "Friends"
    end

    test "shows friend in the list", %{conn: conn, user: user} do
      friend =
        insert(:user,
          email_verified_at: DateTime.utc_now() |> DateTime.truncate(:second),
          display_name: "MyBestFriend"
        )

      {low_id, high_id} =
        if user.id < friend.id, do: {user.id, friend.id}, else: {friend.id, user.id}

      low_user = ParkBench.Accounts.get_user!(low_id)
      high_user = ParkBench.Accounts.get_user!(high_id)
      insert(:friendship, user: low_user, friend: high_user)

      {:ok, _view, html} = live(conn, ~p"/profile/#{user.slug}/friends")
      assert html =~ "MyBestFriend"
    end

    test "shows private message when friend list is hidden", %{conn: conn} do
      other = insert(:user, email_verified_at: DateTime.utc_now() |> DateTime.truncate(:second))
      insert(:privacy_setting, user: other, friend_list_visibility: "only_me")

      {:ok, _view, html} = live(conn, ~p"/profile/#{other.slug}/friends")
      assert html =~ "friend list is private"
    end

    test "friends can see friend list when set to friends visibility", %{conn: conn, user: user} do
      friend =
        insert(:user,
          email_verified_at: DateTime.utc_now() |> DateTime.truncate(:second),
          display_name: "VisibleFriend"
        )

      insert(:privacy_setting, user: friend, friend_list_visibility: "friends")

      # Create friendship
      {low_id, high_id} =
        if user.id < friend.id, do: {user.id, friend.id}, else: {friend.id, user.id}

      low_user = ParkBench.Accounts.get_user!(low_id)
      high_user = ParkBench.Accounts.get_user!(high_id)
      insert(:friendship, user: low_user, friend: high_user)

      {:ok, _view, html} = live(conn, ~p"/profile/#{friend.slug}/friends")
      refute html =~ "friend list is private"
    end
  end
end
