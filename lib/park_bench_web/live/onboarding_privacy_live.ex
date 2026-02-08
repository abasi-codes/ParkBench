defmodule ParkBenchWeb.OnboardingPrivacyLive do
  use ParkBenchWeb, :live_view

  alias ParkBench.Privacy

  @privacy_fields [
    {:profile_visibility, "Profile Visibility", "Who can see your profile page"},
    {:bio_visibility, "Bio", "Who can see your bio information"},
    {:friend_list_visibility, "Friend List", "Who can see your list of friends"},
    {:wall_posting, "Wall Posting", "Who can write on your wall"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    if user.onboarding_completed_at do
      {:ok, push_navigate(socket, to: "/feed")}
    else
      settings = Privacy.get_privacy_settings(user.id)

      {:ok,
       socket
       |> assign(:page_title, "Privacy Settings")
       |> assign(:settings, settings)
       |> assign(:privacy_fields, @privacy_fields)
       |> assign(:saving, false)}
    end
  end

  @impl true
  def handle_event("save_and_continue", params, socket) do
    user = socket.assigns.current_user

    case Privacy.update_privacy_settings(user.id, params) do
      {:ok, _settings} ->
        {:noreply, push_navigate(socket, to: "/onboarding/profile-setup")}

      {:error, _changeset} ->
        {:noreply,
         put_flash(socket, :error, "Could not save privacy settings. Please try again.")}
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
          <span class="onboarding-step active">3. Privacy</span>
          <span class="onboarding-step-separator">&rarr;</span>
          <span class="onboarding-step">4. Profile</span>
        </div>
        <div class="onboarding-step-label">Step 3 of 4</div>
      </div>

      <div class="content-box-padded">
        <h1 style="font-size: 18px; font-weight: bold; color: #3b5998; margin-bottom: 12px;">
          Privacy Settings
        </h1>

        <p style="font-size: 11px; color: #333; line-height: 1.5; margin-bottom: 12px;">
          Control who can see your information. You can always change these later
          in Settings &rarr; Privacy.
        </p>

        <form phx-submit="save_and_continue">
          <div :for={{field, label, description} <- @privacy_fields} class="settings-row">
            <div style="flex: 1;">
              <div class="settings-row-label">{label}</div>
              <div class="form-help" style="margin-top: 0; margin-bottom: 4px;">
                {description}
              </div>
            </div>
            <div>
              <select name={Atom.to_string(field)} class="form-select">
                <option
                  :for={opt <- Privacy.visibility_options()}
                  value={opt}
                  selected={Map.get(@settings, field) == opt}
                >
                  {format_option(opt)}
                </option>
              </select>
            </div>
          </div>

          <div class="alert alert-info" style="font-size: 11px; margin-top: 12px;">
            These are just the key settings. You can fine-tune all privacy options
            (birthday, email, phone, education, etc.) from the full Privacy Settings
            page after onboarding.
          </div>

          <div class="form-actions" style="justify-content: space-between;">
            <a href="/onboarding/guidelines" class="btn btn-gray">
              &larr; Back
            </a>
            <button type="submit" class="btn btn-blue">
              Next &rarr;
            </button>
          </div>
        </form>
      </div>
    </div>
    """
  end

  defp format_option("everyone"), do: "Everyone"
  defp format_option("friends"), do: "Friends"
  defp format_option("only_me"), do: "Only Me"
  defp format_option(other), do: String.capitalize(String.replace(other, "_", " "))
end
