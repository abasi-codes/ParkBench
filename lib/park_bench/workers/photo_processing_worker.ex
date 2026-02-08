defmodule ParkBench.Workers.PhotoProcessingWorker do
  @moduledoc "Generates thumbnails (200x200, 50x50) and strips EXIF data via libvips"
  use Oban.Worker, queue: :photos, max_attempts: 3

  alias ParkBench.Repo
  alias ParkBench.Accounts.ProfilePhoto

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"photo_id" => photo_id, "file_path" => file_path} = args}) do
    schema = Map.get(args, "schema", "profile_photo")

    photo =
      case schema do
        "photo" -> Repo.get!(ParkBench.Media.Photo, photo_id)
        _ -> Repo.get!(ProfilePhoto, photo_id)
      end

    with {:ok, image} <- Image.open(file_path),
         # Strip EXIF
         {:ok, stripped} <- Image.remove_metadata(image),
         # Generate 200x200 thumbnail
         {:ok, thumb_200} <- Image.thumbnail(stripped, "200x200", crop: :center),
         thumb_200_path = generate_temp_path("thumb_200"),
         :ok <- Image.write(thumb_200, thumb_200_path),
         # Generate 50x50 thumbnail
         {:ok, thumb_50} <- Image.thumbnail(stripped, "50x50", crop: :center),
         thumb_50_path = generate_temp_path("thumb_50"),
         :ok <- Image.write(thumb_50, thumb_50_path) do
      # Upload to S3 (simplified — in production, use ExAws)
      bucket = Application.get_env(:park_bench, :s3_bucket)
      thumb_200_key = "photos/#{photo.user_id}/#{photo.id}_200x200.jpg"
      thumb_50_key = "photos/#{photo.user_id}/#{photo.id}_50x50.jpg"

      # Upload thumbnails
      upload_to_s3(thumb_200_path, bucket, thumb_200_key)
      upload_to_s3(thumb_50_path, bucket, thumb_50_key)

      # Update photo record
      photo
      |> Ecto.Changeset.change(%{
        thumb_200_url: s3_url(bucket, thumb_200_key),
        thumb_50_url: s3_url(bucket, thumb_50_key)
      })
      |> Repo.update!()

      # Clean up temp files
      File.rm(thumb_200_path)
      File.rm(thumb_50_path)

      :ok
    else
      error ->
        require Logger
        Logger.error("Photo processing failed for #{photo_id}: #{inspect(error)}")
        {:error, error}
    end
  end

  defp generate_temp_path(prefix) do
    Path.join(
      System.tmp_dir!(),
      "#{prefix}_#{:crypto.strong_rand_bytes(8) |> Base.hex_encode32(case: :lower)}.jpg"
    )
  end

  defp upload_to_s3(file_path, bucket, key) do
    file_path
    |> ExAws.S3.Upload.stream_file()
    |> ExAws.S3.upload(bucket, key, content_type: "image/jpeg")
    |> ExAws.request()
  end

  defp s3_url(_bucket, key) do
    "/uploads/#{key}"
  end
end
