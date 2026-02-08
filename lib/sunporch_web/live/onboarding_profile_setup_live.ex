defmodule SunporchWeb.OnboardingProfileSetupLive do
  use SunporchWeb, :live_view

  alias Sunporch.Accounts

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    if user.onboarding_completed_at do
      {:ok, push_navigate(socket, to: "/feed")}
    else
      {:ok, profile} = Accounts.get_or_create_profile(user.id)

      {:ok,
       socket
       |> assign(:page_title, "Set Up Your Profile")
       |> assign(:profile, profile)
       |> allow_upload(:photo,
         accept: ~w(.jpg .jpeg .png .webp),
         max_file_size: 10_000_000,
         max_entries: 1
       )}
    end
  end

  @impl true
  def handle_event("finish", params, socket) do
    user = socket.assigns.current_user

    # Handle optional photo upload
    uploaded_files =
      consume_uploaded_entries(socket, :photo, fn %{path: path}, _entry ->
        dest = Path.join(System.tmp_dir!(), "sunporch_onboarding_#{Ecto.UUID.generate()}.jpg")
        File.cp!(path, dest)
        {:ok, dest}
      end)

    case uploaded_files do
      [file_path] -> Accounts.upload_profile_photo(user.id, file_path)
      _ -> :ok
    end

    # Save profile fields (ignore empty strings)
    profile_attrs =
      params
      |> Map.take(["bio", "hometown", "current_city", "birthday"])
      |> Enum.reject(fn {_k, v} -> v == "" end)
      |> Map.new()

    case Accounts.update_profile(user.id, profile_attrs) do
      {:ok, _profile} ->
        case Accounts.mark_onboarding_complete(user) do
          {:ok, _user} ->
            {:noreply,
             socket
             |> put_flash(:info, "Welcome to Sunporch! Your account is all set.")
             |> push_navigate(to: "/feed")}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Something went wrong. Please try again.")}
        end

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not save profile. Please try again.")}
    end
  end

  def handle_event("validate_photo", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("skip", _params, socket) do
    user = socket.assigns.current_user

    case Accounts.mark_onboarding_complete(user) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Welcome to Sunporch! You can set up your profile anytime from Settings.")
         |> push_navigate(to: "/feed")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Something went wrong. Please try again.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="single-column" style="max-width: 600px; margin: 0 auto;">
      <div class="onboarding-progress">
        <div class="onboarding-steps">
          <span class="onboarding-step completed">1. Welcome</span>
          <span class="onboarding-step-separator">&rarr;</span>
          <span class="onboarding-step completed">2. Guidelines</span>
          <span class="onboarding-step-separator">&rarr;</span>
          <span class="onboarding-step completed">3. Privacy</span>
          <span class="onboarding-step-separator">&rarr;</span>
          <span class="onboarding-step active">4. Profile</span>
        </div>
        <div class="onboarding-step-label">Step 4 of 4</div>
      </div>

      <div class="content-box-padded">
        <h1 style="font-size: 18px; font-weight: bold; color: #3b5998; margin-bottom: 12px;">
          Set Up Your Profile
        </h1>

        <p style="font-size: 11px; color: #333; line-height: 1.5; margin-bottom: 12px;">
          Tell people a little about yourself. All fields are optional -- you can
          always fill these in later from your profile settings.
        </p>

        <form phx-submit="finish" phx-change="validate_photo">
          <div class="form-group">
            <label>Profile Photo (optional)</label>
            <.live_file_input upload={@uploads.photo} />
            <div :for={entry <- @uploads.photo.entries} style="margin-top: 4px;">
              <div style="font-size:11px;color:#333;">{entry.client_name}</div>
              <progress value={entry.progress} max="100" style="width:200px;" />
            </div>
            <span class="form-help">Upload a photo so friends can recognize you. JPG, PNG, or WebP (max 10MB).</span>
          </div>

          <div class="form-group">
            <label>Bio</label>
            <textarea
              name="bio"
              class="form-textarea"
              rows="4"
              maxlength="2000"
              placeholder="Write a little about yourself..."
            >{@profile && @profile.bio}</textarea>
            <span class="form-help">What should people know about you?</span>
          </div>

          <div class="form-group">
            <label>Hometown</label>
            <input
              type="text"
              name="hometown"
              class="form-input"
              value={@profile && @profile.hometown}
              maxlength="200"
              placeholder="Where are you from?"
            />
          </div>

          <div class="form-group">
            <label>Current City</label>
            <input
              type="text"
              name="current_city"
              class="form-input"
              value={@profile && @profile.current_city}
              maxlength="200"
              placeholder="Where do you live now?"
            />
          </div>

          <div class="form-group">
            <label>Birthday</label>
            <input
              type="date"
              name="birthday"
              class="form-input"
              value={@profile && @profile.birthday}
              style="width: auto;"
            />
            <span class="form-help">You can control who sees this in Privacy Settings.</span>
          </div>

          <div class="section-divider"></div>

          <div class="form-actions" style="justify-content: space-between;">
            <a href="/onboarding/privacy" class="btn btn-gray">
              &larr; Back
            </a>
            <div class="btn-group">
              <button type="button" phx-click="skip" class="btn btn-gray">
                Skip for now
              </button>
              <button type="submit" class="btn btn-green">
                Finish Setup
              </button>
            </div>
          </div>
        </form>
      </div>
    </div>
    """
  end
end
