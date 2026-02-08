defmodule SunporchWeb.SettingsAccountLive do
  use SunporchWeb, :live_view

  alias Sunporch.Accounts

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, "Account Settings")}
  end

  @impl true
  def handle_event("update_display_name", %{"display_name" => name}, socket) do
    case Accounts.update_display_name(socket.assigns.current_user, name) do
      {:ok, user} ->
        {:noreply, socket |> assign(:current_user, user) |> put_flash(:info, "Display name updated.")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Display name must be between 1 and 100 characters.")}
    end
  end

  def handle_event("change_email", %{"email" => email, "current_password" => password}, socket) do
    case Accounts.change_email(socket.assigns.current_user, email, password) do
      {:ok, user} ->
        {:noreply, socket |> assign(:current_user, user) |> put_flash(:info, "Email updated.")}

      {:error, :invalid_current_password} ->
        {:noreply, put_flash(socket, :error, "Current password is incorrect.")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not update email. It may already be in use.")}
    end
  end

  def handle_event("change_password", %{"current_password" => current, "new_password" => new_pw, "new_password_confirmation" => confirm}, socket) do
    case Accounts.change_password(socket.assigns.current_user, current, new_pw, confirm) do
      {:ok, _user} ->
        {:noreply, put_flash(socket, :info, "Password changed successfully.")}

      {:error, :invalid_current_password} ->
        {:noreply, put_flash(socket, :error, "Current password is incorrect.")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not change password. New password must be at least 8 characters and match confirmation.")}
    end
  end

  def handle_event("delete_account", %{"password" => password}, socket) do
    case Accounts.delete_account(socket.assigns.current_user, password) do
      {:ok, _} ->
        {:noreply, socket |> redirect(to: "/")}

      {:error, :invalid_current_password} ->
        {:noreply, put_flash(socket, :error, "Current password is incorrect.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not delete account.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="settings-page two-column">
      <aside class="settings-nav sidebar-left">
        <.sidebar_box title="Settings">
          <ul class="sidebar-nav">
            <li class="sidebar-nav-item active"><a href="/settings/account">Account</a></li>
            <li class="sidebar-nav-item"><a href="/settings/profile">Profile</a></li>
            <li class="sidebar-nav-item"><a href="/settings/privacy">Privacy</a></li>
          </ul>
        </.sidebar_box>
      </aside>

      <section class="settings-content main-content">
        <h1>Account Settings</h1>

        <div class="info-section">
          <h2>Account Information</h2>
          <div class="info-row" style="padding:16px 20px;">
            <span class="info-label">Member Since:</span>
            <span>{Calendar.strftime(@current_user.inserted_at, "%B %d, %Y")}</span>
          </div>
        </div>

        <div class="info-section">
          <h2>Display Name</h2>
          <form phx-submit="update_display_name">
            <div class="form-group">
              <label for="display_name">Display Name</label>
              <input type="text" id="display_name" name="display_name" value={@current_user.display_name} maxlength="100" required class="form-input" />
            </div>
            <button type="submit" class="btn btn-blue">Update Name</button>
          </form>
        </div>

        <div class="info-section">
          <h2>Change Email</h2>
          <p class="form-help" style="padding:0 20px;">Current email: {@current_user.email}</p>
          <form phx-submit="change_email">
            <div class="form-group">
              <label for="new_email">New Email</label>
              <input type="email" id="new_email" name="email" required class="form-input" />
            </div>
            <div class="form-group">
              <label for="email_password">Current Password</label>
              <input type="password" id="email_password" name="current_password" required class="form-input" />
            </div>
            <button type="submit" class="btn btn-blue">Update Email</button>
          </form>
        </div>

        <div class="info-section">
          <h2>Change Password</h2>
          <form phx-submit="change_password">
            <div class="form-group">
              <label for="current_password">Current Password</label>
              <input type="password" id="current_password" name="current_password" required class="form-input" />
            </div>
            <div class="form-group">
              <label for="new_password">New Password</label>
              <input type="password" id="new_password" name="new_password" minlength="8" required class="form-input" />
            </div>
            <div class="form-group">
              <label for="new_password_confirmation">Confirm New Password</label>
              <input type="password" id="new_password_confirmation" name="new_password_confirmation" minlength="8" required class="form-input" />
            </div>
            <button type="submit" class="btn btn-blue">Change Password</button>
          </form>
        </div>

        <div class="info-section">
          <h2>Delete Account</h2>
          <p class="form-help" style="padding:0 20px;">This action is permanent and cannot be undone.</p>
          <form phx-submit="delete_account" data-confirm="Are you sure you want to permanently delete your account?">
            <div class="form-group">
              <label for="delete_password">Enter your password to confirm</label>
              <input type="password" id="delete_password" name="password" required class="form-input" />
            </div>
            <button type="submit" class="btn btn-small btn-danger">Delete My Account</button>
          </form>
        </div>
      </section>
    </div>
    """
  end
end
