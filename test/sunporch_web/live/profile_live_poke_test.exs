defmodule SunporchWeb.ProfileLivePokeTest do
  use SunporchWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "poke button on profile" do
    setup %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      friend = insert(:user, email_verified_at: DateTime.utc_now() |> DateTime.truncate(:second), display_name: "PokeFriend")

      # Create friendship
      {low_id, high_id} = if user.id < friend.id, do: {user.id, friend.id}, else: {friend.id, user.id}
      low_user = Sunporch.Accounts.get_user!(low_id)
      high_user = Sunporch.Accounts.get_user!(high_id)
      insert(:friendship, user: low_user, friend: high_user)

      %{conn: conn, user: user, friend: friend}
    end

    test "shows poke button for friends", %{conn: conn, friend: friend} do
      {:ok, _view, html} = live(conn, ~p"/profile/#{friend.slug}")
      assert html =~ "Poke"
      refute html =~ "Poked!"
    end

    test "clicking poke sends poke and shows poked state", %{conn: conn, friend: friend} do
      {:ok, view, _html} = live(conn, ~p"/profile/#{friend.slug}")

      html = view |> element("button", "Poke") |> render_click()
      assert html =~ "Poked!"
    end

    test "does not show poke button for non-friends", %{conn: conn} do
      stranger = insert(:user, email_verified_at: DateTime.utc_now() |> DateTime.truncate(:second))

      {:ok, _view, html} = live(conn, ~p"/profile/#{stranger.slug}")
      refute html =~ "phx-click=\"send_poke\""
    end

    test "shows poked state if already poked", %{conn: conn, user: user, friend: friend} do
      Sunporch.Social.poke(user.id, friend.id)

      {:ok, _view, html} = live(conn, ~p"/profile/#{friend.slug}")
      assert html =~ "Poked!"
    end
  end
end
