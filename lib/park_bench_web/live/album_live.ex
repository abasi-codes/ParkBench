defmodule ParkBenchWeb.AlbumLive do
  use ParkBenchWeb, :live_view

  alias ParkBench.Media

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:album, nil)
     |> assign(:photos, [])
     |> assign(:is_owner, false)
     |> assign(:show_upload_form, false)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "Create Album")
    |> assign(:changeset, Media.PhotoAlbum.changeset(%Media.PhotoAlbum{}, %{}))
  end

  defp apply_action(socket, :show, %{"id" => id}) do
    album = Media.get_album!(id)
    photos = Media.list_photos(album.id)
    is_owner = socket.assigns.current_user.id == album.user_id

    socket
    |> assign(:page_title, album.title)
    |> assign(:album, album)
    |> assign(:photos, photos)
    |> assign(:is_owner, is_owner)
    |> then(fn s ->
      if is_owner and connected?(socket) do
        allow_upload(s, :photos,
          accept: ~w(.jpg .jpeg .png .webp),
          max_file_size: 10_000_000,
          max_entries: 10
        )
      else
        s
      end
    end)
  end

  @impl true
  def handle_event("create_album", %{"title" => title} = params, socket) do
    attrs = %{title: title, description: Map.get(params, "description", "")}

    case Media.create_album(socket.assigns.current_user.id, attrs) do
      {:ok, album} ->
        {:noreply, push_navigate(socket, to: "/albums/#{album.id}")}

      {:error, changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  def handle_event("delete_album", _, socket) do
    album = socket.assigns.album

    if socket.assigns.is_owner do
      {:ok, _} = Media.delete_album(album)
      user = ParkBench.Accounts.get_user!(album.user_id)
      {:noreply, push_navigate(socket, to: "/profile/#{user.slug}/photos")}
    else
      {:noreply, socket}
    end
  end

  def handle_event("delete_photo", %{"id" => photo_id}, socket) do
    if socket.assigns.is_owner do
      Media.delete_photo(photo_id, socket.assigns.current_user.id)
      photos = Media.list_photos(socket.assigns.album.id)
      album = Media.get_album!(socket.assigns.album.id)
      {:noreply, assign(socket, photos: photos, album: album)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("set_cover", %{"id" => photo_id}, socket) do
    if socket.assigns.is_owner do
      {:ok, album} = Media.set_cover_photo(photo_id, socket.assigns.current_user.id)
      {:noreply, assign(socket, :album, album)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("toggle_upload_form", _, socket) do
    {:noreply, assign(socket, :show_upload_form, !socket.assigns.show_upload_form)}
  end

  def handle_event("validate_photos", _, socket) do
    {:noreply, socket}
  end

  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :photos, ref)}
  end

  def handle_event("upload_photos", _, socket) do
    user_id = socket.assigns.current_user.id
    album_id = socket.assigns.album.id

    consume_uploaded_entries(socket, :photos, fn %{path: path}, _entry ->
      Media.upload_photo(user_id, album_id, path)
    end)

    photos = Media.list_photos(album_id)
    album = Media.get_album!(album_id)
    {:noreply, assign(socket, photos: photos, album: album, show_upload_form: false)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="album-page">
      <div :if={@live_action == :new} class="album-create-form">
        <h1>Create New Album</h1>
        <form phx-submit="create_album">
          <div class="form-group">
            <label for="title">Album Title</label>
            <input type="text" name="title" id="title" maxlength="100" required />
          </div>
          <div class="form-group">
            <label for="description">Description (optional)</label>
            <textarea name="description" id="description" rows="3" maxlength="1000"></textarea>
          </div>
          <button type="submit" class="btn btn-blue">Create Album</button>
          <a href="javascript:history.back()" class="btn btn-gray">Cancel</a>
        </form>
      </div>

      <div :if={@live_action == :show && @album} class="album-show">
        <div class="album-header">
          <h1>{@album.title}</h1>
          <p :if={@album.description} class="album-description">{@album.description}</p>
          <p class="album-photo-count">
            {@album.photo_count} photo{if @album.photo_count != 1, do: "s"}
          </p>

          <div :if={@is_owner} class="album-actions">
            <button phx-click="toggle_upload_form" class="btn btn-blue">Upload Photos</button>
            <button
              phx-click="delete_album"
              data-confirm="Delete this entire album?"
              class="btn btn-gray"
            >
              Delete Album
            </button>
          </div>
        </div>

        <div :if={@is_owner && @show_upload_form} class="upload-form">
          <form phx-submit="upload_photos" phx-change="validate_photos">
            <.live_file_input upload={@uploads.photos} />
            <button type="submit" class="btn btn-blue">Upload</button>
            <button type="button" phx-click="toggle_upload_form" class="btn btn-gray">Cancel</button>
          </form>

          <div :for={entry <- @uploads.photos.entries} class="upload-entry">
            <span>{entry.client_name}</span>
            <button
              type="button"
              phx-click="cancel_upload"
              phx-value-ref={entry.ref}
              class="btn btn-small btn-gray"
            >
              Cancel
            </button>
          </div>
        </div>

        <div :if={@photos == []} class="empty-album">
          <p>No photos in this album yet.</p>
        </div>

        <div :if={@photos != []} class="photo-grid">
          <div :for={photo <- @photos} class="photo-card">
            <img
              src={photo.thumb_200_url || photo.original_url}
              alt={photo.caption || "Photo"}
              class="photo-thumb"
            />
            <p :if={photo.caption} class="photo-caption">{photo.caption}</p>
            <div :if={@is_owner} class="photo-actions">
              <button phx-click="set_cover" phx-value-id={photo.id} class="btn btn-small btn-gray">
                Set Cover
              </button>
              <button
                phx-click="delete_photo"
                phx-value-id={photo.id}
                data-confirm="Delete this photo?"
                class="btn btn-small btn-gray"
              >
                Delete
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
