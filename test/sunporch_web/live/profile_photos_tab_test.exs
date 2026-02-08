defmodule SunporchWeb.ProfilePhotosTabTest do
  use SunporchWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "photos tab" do
    setup %{conn: conn} do
      register_and_log_in_user(%{conn: conn})
    end

    test "shows 'No photo albums yet.' when empty", %{conn: conn, user: user} do
      {:ok, _view, html} = live(conn, ~p"/profile/#{user.slug}/photos")
      assert html =~ "No photo albums yet"
    end

    test "shows album cards with title and count", %{conn: conn, user: user} do
      album = insert(:photo_album, user: user, title: "Summer Pics", photo_count: 5)

      {:ok, _view, html} = live(conn, ~p"/profile/#{user.slug}/photos")
      assert html =~ "Summer Pics"
      assert html =~ "5 photos"
      assert html =~ "/albums/#{album.id}"
    end

    test "shows Create Album button on own profile", %{conn: conn, user: user} do
      {:ok, _view, html} = live(conn, ~p"/profile/#{user.slug}/photos")
      assert html =~ "Create Album"
      assert html =~ "/albums/new"
    end

    test "hides Create Album button on other's profile", %{conn: conn} do
      other = insert(:user, email_verified_at: DateTime.utc_now() |> DateTime.truncate(:second))

      {:ok, _view, html} = live(conn, ~p"/profile/#{other.slug}/photos")
      refute html =~ "Create Album"
    end

    test "shows singular 'photo' for count of 1", %{conn: conn, user: user} do
      insert(:photo_album, user: user, title: "Solo", photo_count: 1)

      {:ok, _view, html} = live(conn, ~p"/profile/#{user.slug}/photos")
      assert html =~ "1 photo"
      refute html =~ "1 photos"
    end
  end
end
