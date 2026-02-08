defmodule ParkBenchWeb.SettingsPrivacyLive do
  use ParkBenchWeb, :live_view

  alias ParkBench.Privacy

  @field_groups [
    {"Profile",
     [
       {:profile_visibility, "Profile Visibility"}
     ]},
    {"Personal Information",
     [
       {:bio_visibility, "Bio"},
       {:interests_visibility, "Interests"},
       {:education_visibility, "Education"},
       {:work_visibility, "Work"},
       {:birthday_visibility, "Birthday"},
       {:hometown_visibility, "Hometown"},
       {:current_city_visibility, "Current City"},
       {:phone_visibility, "Phone Number"},
       {:email_visibility, "Email Address"},
       {:relationship_visibility, "Relationship Status"}
     ]},
    {"Interactions",
     [
       {:wall_posting, "Who can post on your wall"},
       {:friend_list_visibility, "Friend List"}
     ]}
  ]

  @impl true
  def mount(_params, _session, socket) do
    settings = Privacy.get_privacy_settings(socket.assigns.current_user.id)

    {:ok,
     socket
     |> assign(:page_title, "Privacy Settings")
     |> assign(:settings, settings)
     |> assign(:field_groups, @field_groups)}
  end

  @impl true
  def handle_event("update_privacy", params, socket) do
    case Privacy.update_privacy_settings(socket.assigns.current_user.id, params) do
      {:ok, settings} ->
        {:noreply,
         assign(socket, settings: settings) |> put_flash(:info, "Privacy settings updated.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not update settings.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="settings-page two-column">
      <aside class="settings-nav sidebar-left">
        <.sidebar_box title="Settings">
          <ul class="sidebar-nav">
            <li class="sidebar-nav-item"><a href="/settings/account">Account</a></li>
            <li class="sidebar-nav-item"><a href="/settings/profile">Profile</a></li>
            <li class="sidebar-nav-item active"><a href="/settings/privacy">Privacy</a></li>
          </ul>
        </.sidebar_box>
      </aside>

      <section class="settings-content main-content">
        <h1>Privacy Settings</h1>

        <div class="info-section">
          <h2>Privacy Settings</h2>
          <form phx-submit="update_privacy" style="padding:16px 20px;">
            <div :for={{group_name, fields} <- @field_groups} class="privacy-group">
              <div class="privacy-group-title">{group_name}</div>
              <div :for={{field, label} <- fields} class="form-group">
                <label>{label}</label>
                <select name={Atom.to_string(field)} class="form-select">
                  <option
                    :for={opt <- Privacy.visibility_options()}
                    value={opt}
                    selected={Map.get(@settings, field) == opt}
                  >
                    {String.capitalize(String.replace(opt, "_", " "))}
                  </option>
                </select>
              </div>
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
end
