defmodule SunporchWeb.SettingsProfileLive do
  use SunporchWeb, :live_view

  alias Sunporch.Accounts

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    {:ok, profile} = Accounts.get_or_create_profile(user.id)
    current_photo = Accounts.get_current_profile_photo(user.id)

    {:ok,
     socket
     |> assign(:page_title, "Edit Profile")
     |> assign(:profile, profile)
     |> assign(:current_photo, current_photo)
     |> assign(:upload_error, nil)
     |> allow_upload(:photo,
       accept: ~w(.jpg .jpeg .png .webp),
       max_file_size: 10_000_000,
       max_entries: 1
     )}
  end

  @impl true
  def handle_event("save_profile", params, socket) do
    case Accounts.update_profile(socket.assigns.current_user.id, params) do
      {:ok, profile} ->
        {:noreply, assign(socket, :profile, profile) |> put_flash(:info, "Profile updated.")}
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not update profile.")}
    end
  end

  def handle_event("save_photo", _params, socket) do
    user = socket.assigns.current_user

    uploaded_files =
      consume_uploaded_entries(socket, :photo, fn %{path: path}, _entry ->
        dest = Path.join(System.tmp_dir!(), "sunporch_upload_#{Ecto.UUID.generate()}.jpg")
        File.cp!(path, dest)
        {:ok, dest}
      end)

    case uploaded_files do
      [file_path] ->
        case Accounts.upload_profile_photo(user.id, file_path) do
          {:ok, photo} ->
            {:noreply,
             socket
             |> assign(:current_photo, photo)
             |> assign(:upload_error, nil)
             |> put_flash(:info, "Photo uploaded! Thumbnails are being generated.")}

          {:error, _reason} ->
            {:noreply,
             socket
             |> assign(:upload_error, "Upload failed. Please try again.")
             |> put_flash(:error, "Could not upload photo.")}
        end

      _ ->
        {:noreply, put_flash(socket, :error, "Please select a photo.")}
    end
  end

  def handle_event("validate_photo", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :photo, ref)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="settings-page two-column">
      <aside class="settings-nav sidebar-left">
        <.sidebar_box title="Settings">
          <ul class="sidebar-nav">
            <li class="sidebar-nav-item"><a href="/settings/account">Account</a></li>
            <li class="sidebar-nav-item active"><a href="/settings/profile">Profile</a></li>
            <li class="sidebar-nav-item"><a href="/settings/privacy">Privacy</a></li>
          </ul>
        </.sidebar_box>
      </aside>

      <section class="settings-content main-content">
        <h1>Edit Profile</h1>

        <div class="info-section">
          <h2>Profile Photo</h2>
          <div class="settings-photo-section">
            <div :if={@current_photo && @current_photo.thumb_200_url} class="settings-photo-preview">
              <img src={@current_photo.thumb_200_url} alt="Current photo" />
            </div>
            <div :if={!@current_photo || !@current_photo.thumb_200_url} class="settings-photo-placeholder">
              No photo
            </div>

            <div class="settings-photo-upload">
              <form phx-submit="save_photo" phx-change="validate_photo">
                <.live_file_input upload={@uploads.photo} />
                <div :for={entry <- @uploads.photo.entries} class="upload-entry">
                  <div class="upload-entry-name">{entry.client_name}</div>
                  <progress value={entry.progress} max="100" />
                  <button type="button" phx-click="cancel_upload" phx-value-ref={entry.ref} class="btn btn-small btn-gray">Cancel</button>
                  <div :for={err <- upload_errors(@uploads.photo, entry)} class="upload-error">
                    {upload_error_to_string(err)}
                  </div>
                </div>
                <div :for={err <- upload_errors(@uploads.photo)} class="upload-error">
                  {upload_error_to_string(err)}
                </div>
                <div :if={@upload_error} class="upload-error">{@upload_error}</div>
                <button type="submit" class="btn btn-small btn-blue">Upload Photo</button>
              </form>
            </div>
          </div>
          <div :if={@current_photo && @current_photo.ai_detection_status == "pending"} class="settings-ai-status pending">
            AI detection: pending review
          </div>
          <div :if={@current_photo && @current_photo.ai_detection_status == "flagged"} class="settings-ai-status flagged">
            AI detection: flagged — this photo may be AI-generated
          </div>
        </div>

        <div class="info-section">
          <h2>Profile Information</h2>
          <form phx-submit="save_profile">
            <div class="form-group">
              <label>Bio</label>
              <textarea name="bio" rows="4" maxlength="2000" class="form-textarea">{@profile && @profile.bio}</textarea>
            </div>
            <div class="form-group">
              <label>Interests</label>
              <textarea name="interests" rows="3" maxlength="2000" class="form-textarea">{@profile && @profile.interests}</textarea>
            </div>
            <div class="form-group">
              <label>Hometown</label>
              <input type="text" name="hometown" value={@profile && @profile.hometown} maxlength="200" class="form-input" />
            </div>
            <div class="form-group">
              <label>Current City</label>
              <input type="text" name="current_city" value={@profile && @profile.current_city} maxlength="200" class="form-input" />
            </div>
            <div class="form-group">
              <label>Birthday</label>
              <input type="date" name="birthday" value={@profile && @profile.birthday} class="form-input" />
            </div>
            <div class="form-group">
              <label>Gender</label>
              <select name="gender" class="form-select">
                <option value="">Select</option>
                <option value="Male" selected={@profile && @profile.gender == "Male"}>Male</option>
                <option value="Female" selected={@profile && @profile.gender == "Female"}>Female</option>
                <option value="Other" selected={@profile && @profile.gender == "Other"}>Other</option>
              </select>
            </div>
            <div class="form-group">
              <label>Relationship Status</label>
              <select name="relationship_status" class="form-select">
                <option value="">Select</option>
                <option :for={status <- ["Single", "In a Relationship", "Engaged", "Married", "It's Complicated"]}
                        value={status}
                        selected={@profile && @profile.relationship_status == status}>
                  {status}
                </option>
              </select>
            </div>
            <div class="form-group">
              <label>Website</label>
              <input type="url" name="website" value={@profile && @profile.website} maxlength="500" class="form-input" />
            </div>
            <div class="form-actions">
              <button type="submit" class="btn btn-blue">Save Changes</button>
            </div>
          </form>
        </div>
      </section>
    </div>
    """
  end

  defp upload_error_to_string(:too_large), do: "File is too large (max 10MB)."
  defp upload_error_to_string(:too_many_files), do: "Only one file allowed."
  defp upload_error_to_string(:not_accepted), do: "Invalid file type. Use JPG, PNG, or WebP."
  defp upload_error_to_string(_), do: "Upload error."
end
