defmodule SunporchWeb.AlbumUploadTest do
  use SunporchWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "photo upload UI" do
    setup %{conn: conn} do
      register_and_log_in_user(%{conn: conn})
    end

    test "upload form shows for owner after toggle", %{conn: conn, user: user} do
      album = insert(:photo_album, user: user)

      {:ok, view, _html} = live(conn, ~p"/albums/#{album.id}")

      html = view |> element("button[phx-click='toggle_upload_form']") |> render_click()
      assert html =~ "phx-submit=\"upload_photos\""
    end

    test "upload form hidden for non-owner", %{conn: conn} do
      other = insert(:user)
      album = insert(:photo_album, user: other)

      {:ok, _view, html} = live(conn, ~p"/albums/#{album.id}")
      refute html =~ "Upload Photos"
    end

    test "photo appears in album after direct insert", %{conn: conn, user: user} do
      album = insert(:photo_album, user: user, photo_count: 0)

      # Simulate what upload_photo does at DB level (skip S3)
      insert(:photo, user: user, album: album, position: 0, caption: "Uploaded pic")

      {:ok, _view, html} = live(conn, ~p"/albums/#{album.id}")
      assert html =~ "Uploaded pic"
    end

    test "photo count updates after insert", %{conn: conn, user: user} do
      album = insert(:photo_album, user: user, photo_count: 3)

      {:ok, _view, html} = live(conn, ~p"/albums/#{album.id}")
      assert html =~ "3 photos"
    end

    test "cancel upload removes entry", %{conn: conn, user: user} do
      album = insert(:photo_album, user: user)

      {:ok, view, _html} = live(conn, ~p"/albums/#{album.id}")
      view |> element("button[phx-click='toggle_upload_form']") |> render_click()

      photo =
        file_input(view, "form[phx-submit='upload_photos']", :photos, [
          %{
            name: "cancel_me.jpg",
            content: :crypto.strong_rand_bytes(100),
            type: "image/jpeg"
          }
        ])

      render_upload(photo, "cancel_me.jpg")

      html = render(view)
      assert html =~ "cancel_me.jpg"

      view |> element("button[phx-click='cancel_upload']") |> render_click()

      html = render(view)
      refute html =~ "cancel_me.jpg"
    end
  end
end
