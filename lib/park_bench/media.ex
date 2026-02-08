defmodule ParkBench.Media do
  @moduledoc "Photo albums and photos"

  import Ecto.Query
  alias ParkBench.Repo
  alias ParkBench.Media.{PhotoAlbum, Photo}
  alias ParkBench.AIDetection

  # === Albums ===

  def list_albums(user_id) do
    PhotoAlbum
    |> where([a], a.user_id == ^user_id)
    |> order_by([a], desc: a.inserted_at)
    |> Repo.all()
  end

  def get_album!(id), do: Repo.get!(PhotoAlbum, id)

  def get_album(id), do: Repo.get(PhotoAlbum, id)

  def create_album(user_id, attrs) do
    %PhotoAlbum{}
    |> PhotoAlbum.changeset(Map.put(attrs, :user_id, user_id))
    |> Repo.insert()
  end

  def update_album(%PhotoAlbum{} = album, attrs) do
    album
    |> PhotoAlbum.changeset(Map.take(attrs, [:title, :description]))
    |> Repo.update()
  end

  def delete_album(%PhotoAlbum{} = album) do
    Repo.delete(album)
  end

  # === Photos ===

  def list_photos(album_id) do
    Photo
    |> where([p], p.album_id == ^album_id and is_nil(p.deleted_at))
    |> where([p], p.ai_detection_status not in ["hard_rejected"])
    |> order_by([p], asc: p.position, asc: p.inserted_at)
    |> Repo.all()
  end

  def get_photo!(id), do: Repo.get!(Photo, id)

  def upload_photo(user_id, album_id, file_path, attrs \\ %{}) do
    album = get_album!(album_id)

    if album.user_id != user_id do
      {:error, :unauthorized}
    else
      bucket = Application.get_env(:park_bench, :s3_bucket)
      uuid = Ecto.UUID.generate()
      s3_key = "photos/albums/#{user_id}/#{album_id}/#{uuid}.jpg"

      with {:ok, _} <- upload_to_s3(file_path, bucket, s3_key) do
        original_url = "/uploads/#{s3_key}"
        content_hash = hash_file(file_path)

        # Get next position
        max_pos =
          Photo
          |> where([p], p.album_id == ^album_id and is_nil(p.deleted_at))
          |> Repo.aggregate(:max, :position) || -1

        photo_attrs =
          Map.merge(attrs, %{
            user_id: user_id,
            album_id: album_id,
            original_url: original_url,
            content_hash: content_hash,
            position: max_pos + 1
          })

        case %Photo{} |> Photo.changeset(photo_attrs) |> Repo.insert() do
          {:ok, photo} ->
            # Increment photo_count
            from(a in PhotoAlbum, where: a.id == ^album_id)
            |> Repo.update_all(inc: [photo_count: 1])

            # Set as cover if first photo
            if album.cover_photo_id == nil do
              from(a in PhotoAlbum, where: a.id == ^album_id)
              |> Repo.update_all(set: [cover_photo_id: photo.id])
            end

            # Enqueue thumbnail processing
            Oban.insert(
              ParkBench.Workers.PhotoProcessingWorker.new(%{
                "photo_id" => photo.id,
                "file_path" => file_path,
                "schema" => "photo"
              })
            )

            AIDetection.check_image(user_id, "photo", photo.id, original_url)

            {:ok, Repo.reload!(photo)}

          error ->
            error
        end
      end
    end
  end

  def delete_photo(photo_id, user_id) do
    photo = get_photo!(photo_id)

    if photo.user_id != user_id do
      {:error, :unauthorized}
    else
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      {:ok, photo} =
        photo
        |> Ecto.Changeset.change(deleted_at: now)
        |> Repo.update()

      # Decrement photo_count
      from(a in PhotoAlbum, where: a.id == ^photo.album_id)
      |> Repo.update_all(inc: [photo_count: -1])

      # If this was the cover, rotate to next photo
      album = get_album!(photo.album_id)

      if album.cover_photo_id == photo.id do
        next_cover =
          Photo
          |> where([p], p.album_id == ^album.id and is_nil(p.deleted_at) and p.id != ^photo.id)
          |> order_by([p], asc: p.position, asc: p.inserted_at)
          |> limit(1)
          |> Repo.one()

        new_cover_id = if next_cover, do: next_cover.id, else: nil

        from(a in PhotoAlbum, where: a.id == ^album.id)
        |> Repo.update_all(set: [cover_photo_id: new_cover_id])
      end

      {:ok, photo}
    end
  end

  def set_cover_photo(photo_id, user_id) do
    photo = get_photo!(photo_id)

    if photo.user_id != user_id do
      {:error, :unauthorized}
    else
      from(a in PhotoAlbum, where: a.id == ^photo.album_id)
      |> Repo.update_all(set: [cover_photo_id: photo.id])

      {:ok, Repo.reload!(get_album!(photo.album_id))}
    end
  end

  # === Helpers ===

  defp upload_to_s3(file_path, bucket, key) do
    file_path
    |> ExAws.S3.Upload.stream_file()
    |> ExAws.S3.upload(bucket, key, content_type: "image/jpeg")
    |> ExAws.request()
  end

  defp hash_file(file_path) do
    case File.read(file_path) do
      {:ok, content} -> :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)
      _ -> nil
    end
  end
end
