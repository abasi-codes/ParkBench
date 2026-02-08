defmodule Sunporch.Uploader do
  @moduledoc "Local file upload handler — saves files to priv/static/uploads/"

  @upload_dir Path.join(:code.priv_dir(:sunporch), "static/uploads")

  def save_profile_photo(entry, socket) do
    save(entry, socket, "profile_photos")
  end

  def save_cover_photo(entry, socket) do
    save(entry, socket, "cover_photos")
  end

  def save_post_photo(entry, socket) do
    save(entry, socket, "post_photos")
  end

  defp save(entry, socket, type) do
    user_id = socket.assigns.current_user.id
    uuid = Ecto.UUID.generate()
    ext = Path.extname(entry.client_name) |> String.downcase()
    filename = "#{uuid}#{ext}"
    dir = Path.join([@upload_dir, type, user_id])
    File.mkdir_p!(dir)
    dest = Path.join(dir, filename)

    Phoenix.LiveView.consume_uploaded_entry(socket, entry, fn %{path: path} ->
      File.cp!(path, dest)
      {:ok, "/uploads/#{type}/#{user_id}/#{filename}"}
    end)
  end

  def generate_thumb(source_path, dest_path, max_size) do
    File.mkdir_p!(Path.dirname(dest_path))

    case Image.open!(source_path) |> Image.thumbnail(max_size) do
      {:ok, thumb} -> Image.write(thumb, dest_path)
      {:error, _} = err -> err
    end
  rescue
    _ -> {:error, :thumbnail_failed}
  end

  def full_path(url_path) do
    Path.join([:code.priv_dir(:sunporch), "static", String.trim_leading(url_path, "/")])
  end
end
