defmodule ParkBench.MediaTest do
  use ParkBench.DataCase, async: true

  alias ParkBench.Media
  alias ParkBench.Media.{PhotoAlbum, Photo}

  import ParkBench.Factory

  # === Album CRUD ===

  describe "create_album/2" do
    test "creates album with valid attrs" do
      user = insert(:user)
      {:ok, album} = Media.create_album(user.id, %{title: "Summer 2008"})

      assert album.title == "Summer 2008"
      assert album.user_id == user.id
      assert album.photo_count == 0
      assert album.cover_photo_id == nil
    end

    test "rejects blank title" do
      user = insert(:user)
      {:error, changeset} = Media.create_album(user.id, %{title: ""})
      assert errors_on(changeset).title != []
    end

    test "rejects title over 100 chars" do
      user = insert(:user)
      {:error, changeset} = Media.create_album(user.id, %{title: String.duplicate("a", 101)})
      assert errors_on(changeset).title != []
    end

    test "accepts description up to 1000 chars" do
      user = insert(:user)

      {:ok, album} =
        Media.create_album(user.id, %{title: "Test", description: String.duplicate("a", 1000)})

      assert String.length(album.description) == 1000
    end

    test "rejects description over 1000 chars" do
      user = insert(:user)

      {:error, changeset} =
        Media.create_album(user.id, %{title: "Test", description: String.duplicate("a", 1001)})

      assert errors_on(changeset).description != []
    end
  end

  describe "update_album/2" do
    test "updates title and description" do
      user = insert(:user)
      {:ok, album} = Media.create_album(user.id, %{title: "Old Title"})
      {:ok, updated} = Media.update_album(album, %{title: "New Title", description: "New desc"})

      assert updated.title == "New Title"
      assert updated.description == "New desc"
    end
  end

  describe "delete_album/1" do
    test "hard deletes album" do
      user = insert(:user)
      {:ok, album} = Media.create_album(user.id, %{title: "To Delete"})
      {:ok, _} = Media.delete_album(album)

      assert Media.get_album(album.id) == nil
    end

    test "cascade deletes photos when album deleted" do
      user = insert(:user)
      {:ok, album} = Media.create_album(user.id, %{title: "With Photos"})

      insert(:photo, user: user, album: album, position: 0)
      insert(:photo, user: user, album: album, position: 1)

      {:ok, _} = Media.delete_album(album)

      assert ParkBench.Repo.all(Photo) == []
    end
  end

  describe "list_albums/1" do
    test "returns albums ordered by inserted_at desc" do
      user = insert(:user)
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      {:ok, a1} = Media.create_album(user.id, %{title: "First"})

      ParkBench.Repo.update!(
        Ecto.Changeset.change(a1, inserted_at: DateTime.add(now, -10, :second))
      )

      {:ok, a2} = Media.create_album(user.id, %{title: "Second"})

      ParkBench.Repo.update!(
        Ecto.Changeset.change(a2, inserted_at: DateTime.add(now, -5, :second))
      )

      {:ok, a3} = Media.create_album(user.id, %{title: "Third"})
      ParkBench.Repo.update!(Ecto.Changeset.change(a3, inserted_at: now))

      albums = Media.list_albums(user.id)
      assert Enum.map(albums, & &1.id) == [a3.id, a2.id, a1.id]
    end

    test "returns only user's albums" do
      user1 = insert(:user)
      user2 = insert(:user)
      {:ok, _} = Media.create_album(user1.id, %{title: "User1 Album"})
      {:ok, _} = Media.create_album(user2.id, %{title: "User2 Album"})

      assert length(Media.list_albums(user1.id)) == 1
    end
  end

  describe "get_album!/1" do
    test "returns album by id" do
      user = insert(:user)
      {:ok, album} = Media.create_album(user.id, %{title: "Test"})

      fetched = Media.get_album!(album.id)
      assert fetched.id == album.id
    end

    test "raises on invalid id" do
      assert_raise Ecto.NoResultsError, fn ->
        Media.get_album!(Ecto.UUID.generate())
      end
    end
  end

  # === Photo CRUD ===

  describe "list_photos/1" do
    test "returns photos ordered by position asc" do
      user = insert(:user)
      album = insert(:photo_album, user: user)

      p1 = insert(:photo, user: user, album: album, position: 2)
      p2 = insert(:photo, user: user, album: album, position: 0)
      p3 = insert(:photo, user: user, album: album, position: 1)

      photos = Media.list_photos(album.id)
      assert Enum.map(photos, & &1.id) == [p2.id, p3.id, p1.id]
    end

    test "excludes soft-deleted photos" do
      user = insert(:user)
      album = insert(:photo_album, user: user)

      insert(:photo, user: user, album: album, position: 0)

      insert(:photo,
        user: user,
        album: album,
        position: 1,
        deleted_at: DateTime.utc_now() |> DateTime.truncate(:second)
      )

      assert length(Media.list_photos(album.id)) == 1
    end

    test "excludes hard_rejected photos" do
      user = insert(:user)
      album = insert(:photo_album, user: user)

      insert(:photo, user: user, album: album, position: 0)
      insert(:photo, user: user, album: album, position: 1, ai_detection_status: "hard_rejected")

      assert length(Media.list_photos(album.id)) == 1
    end
  end

  describe "delete_photo/2" do
    test "soft deletes photo" do
      user = insert(:user)
      album = insert(:photo_album, user: user, photo_count: 1)
      photo = insert(:photo, user: user, album: album, position: 0)

      {:ok, deleted} = Media.delete_photo(photo.id, user.id)
      assert deleted.deleted_at != nil
    end

    test "decrements photo_count" do
      user = insert(:user)
      album = insert(:photo_album, user: user, photo_count: 2)
      photo = insert(:photo, user: user, album: album, position: 0)

      Media.delete_photo(photo.id, user.id)
      updated_album = Media.get_album!(album.id)
      assert updated_album.photo_count == 1
    end

    test "rotates cover photo when cover deleted" do
      user = insert(:user)
      album = insert(:photo_album, user: user, photo_count: 2)
      p1 = insert(:photo, user: user, album: album, position: 0)
      p2 = insert(:photo, user: user, album: album, position: 1)

      # Set p1 as cover
      ParkBench.Repo.update_all(
        from(a in PhotoAlbum, where: a.id == ^album.id),
        set: [cover_photo_id: p1.id]
      )

      Media.delete_photo(p1.id, user.id)
      updated_album = Media.get_album!(album.id)
      assert updated_album.cover_photo_id == p2.id
    end

    test "cannot delete other user's photo" do
      user = insert(:user)
      other = insert(:user)
      album = insert(:photo_album, user: user, photo_count: 1)
      photo = insert(:photo, user: user, album: album, position: 0)

      assert {:error, :unauthorized} = Media.delete_photo(photo.id, other.id)
    end
  end

  describe "set_cover_photo/2" do
    test "sets cover photo on album" do
      user = insert(:user)
      album = insert(:photo_album, user: user)
      photo = insert(:photo, user: user, album: album, position: 0)

      {:ok, updated_album} = Media.set_cover_photo(photo.id, user.id)
      assert updated_album.cover_photo_id == photo.id
    end

    test "cannot set cover on other user's album" do
      user = insert(:user)
      other = insert(:user)
      album = insert(:photo_album, user: user)
      photo = insert(:photo, user: user, album: album, position: 0)

      assert {:error, :unauthorized} = Media.set_cover_photo(photo.id, other.id)
    end
  end
end
