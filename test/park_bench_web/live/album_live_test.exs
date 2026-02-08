defmodule ParkBenchWeb.AlbumLiveTest do
  use ParkBenchWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "album creation" do
    setup %{conn: conn} do
      register_and_log_in_user(%{conn: conn})
    end

    test "renders album creation form", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/albums/new")
      assert html =~ "Create New Album"
      assert html =~ "Album Title"
    end

    test "creates album and redirects", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/albums/new")

      view
      |> form("form[phx-submit='create_album']", %{
        title: "My New Album",
        description: "A test album"
      })
      |> render_submit()

      {path, _flash} = assert_redirect(view)
      assert path =~ "/albums/"
    end

    test "rejects blank title", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/albums/new")

      html =
        view
        |> form("form[phx-submit='create_album']", %{title: ""})
        |> render_submit()

      # Form stays on page (no redirect)
      assert html =~ "Create New Album"
    end
  end

  describe "album show" do
    setup %{conn: conn} do
      register_and_log_in_user(%{conn: conn})
    end

    test "renders album with photos", %{conn: conn, user: user} do
      album = insert(:photo_album, user: user, title: "My Album", photo_count: 1)
      insert(:photo, user: user, album: album, position: 0, caption: "Beach day")

      {:ok, _view, html} = live(conn, ~p"/albums/#{album.id}")
      assert html =~ "My Album"
      assert html =~ "Beach day"
    end

    test "owner sees delete and cover buttons", %{conn: conn, user: user} do
      album = insert(:photo_album, user: user, photo_count: 1)
      insert(:photo, user: user, album: album, position: 0)

      {:ok, _view, html} = live(conn, ~p"/albums/#{album.id}")
      assert html =~ "Delete Album"
      assert html =~ "Set Cover"
      assert html =~ "Delete"
    end

    test "non-owner cannot see management buttons", %{conn: conn} do
      other = insert(:user)
      album = insert(:photo_album, user: other, photo_count: 1)
      insert(:photo, user: other, album: album, position: 0)

      {:ok, _view, html} = live(conn, ~p"/albums/#{album.id}")
      refute html =~ "Delete Album"
      refute html =~ "Set Cover"
      refute html =~ "Upload Photos"
    end

    test "owner can delete photo (soft delete)", %{conn: conn, user: user} do
      album = insert(:photo_album, user: user, photo_count: 1)
      photo = insert(:photo, user: user, album: album, position: 0, caption: "Deletable")

      {:ok, view, _html} = live(conn, ~p"/albums/#{album.id}")

      view
      |> element("button[phx-click='delete_photo'][phx-value-id='#{photo.id}']")
      |> render_click()

      html = render(view)
      refute html =~ "Deletable"
    end

    test "owner can delete album and redirect", %{conn: conn, user: user} do
      album = insert(:photo_album, user: user)

      {:ok, view, _html} = live(conn, ~p"/albums/#{album.id}")

      view
      |> element("button[phx-click='delete_album']")
      |> render_click()

      {path, _flash} = assert_redirect(view)
      assert path =~ "/profile/"
    end
  end
end
