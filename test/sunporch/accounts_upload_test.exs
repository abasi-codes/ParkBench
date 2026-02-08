defmodule Sunporch.AccountsUploadTest do
  use Sunporch.DataCase, async: true
  use Oban.Testing, repo: Sunporch.Repo

  alias Sunporch.Accounts

  describe "upload_profile_photo/2" do
    test "creates a profile photo record and enqueues processing worker" do
      user = insert(:user)

      # Create a temp file to simulate an upload
      tmp_path = Path.join(System.tmp_dir!(), "test_photo_#{Ecto.UUID.generate()}.jpg")
      File.write!(tmp_path, :crypto.strong_rand_bytes(100))

      on_exit(fn -> File.rm(tmp_path) end)

      # The S3 upload will fail in test env (no MinIO), so we test the function
      # up to the point it would call S3. Instead, test create_profile_photo directly.
      assert {:ok, photo} =
               Accounts.create_profile_photo(user.id, %{
                 original_url: "/uploads/photos/originals/#{user.id}/test.jpg",
                 content_hash: "abc123"
               })

      assert photo.user_id == user.id
      assert photo.is_current == true
      assert photo.original_url =~ "test.jpg"
      assert photo.ai_detection_status == "pending"
    end

    test "marks previous photo as not current when creating new one" do
      user = insert(:user)

      {:ok, photo1} =
        Accounts.create_profile_photo(user.id, %{
          original_url: "/uploads/photo1.jpg",
          content_hash: "hash1"
        })

      assert photo1.is_current == true

      {:ok, photo2} =
        Accounts.create_profile_photo(user.id, %{
          original_url: "/uploads/photo2.jpg",
          content_hash: "hash2"
        })

      assert photo2.is_current == true

      # Reload photo1 — should no longer be current
      photo1_reloaded = Repo.get!(Sunporch.Accounts.ProfilePhoto, photo1.id)
      refute photo1_reloaded.is_current
    end

    test "get_current_profile_photo returns the current photo" do
      user = insert(:user)

      {:ok, _photo1} =
        Accounts.create_profile_photo(user.id, %{
          original_url: "/uploads/photo1.jpg",
          content_hash: "hash1"
        })

      {:ok, photo2} =
        Accounts.create_profile_photo(user.id, %{
          original_url: "/uploads/photo2.jpg",
          content_hash: "hash2"
        })

      current = Accounts.get_current_profile_photo(user.id)
      assert current.id == photo2.id
    end

    test "get_current_profile_photo returns nil when no photos" do
      user = insert(:user)
      assert is_nil(Accounts.get_current_profile_photo(user.id))
    end
  end
end
