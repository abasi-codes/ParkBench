defmodule SunporchWeb.Admin.UsersLive do
  use SunporchWeb, :live_view

  import Ecto.Query
  alias Sunporch.Repo
  alias Sunporch.Accounts.User

  @impl true
  def mount(_params, _session, socket) do
    users = User |> order_by([u], desc: u.inserted_at) |> limit(50) |> Repo.all()
    {:ok, assign(socket, page_title: "Manage Users", users: users)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="admin-page">
      <h1>Users</h1>
      <table class="admin-table">
        <thead>
          <tr>
            <th>Name</th><th>Email</th><th>Role</th><th>Verified</th><th>AI Flagged</th><th>Joined</th>
          </tr>
        </thead>
        <tbody>
          <tr :for={user <- @users}>
            <td><a href={"/profile/#{user.slug}"}>{user.display_name}</a></td>
            <td>{user.email}</td>
            <td>{user.role}</td>
            <td>{if user.email_verified_at, do: "Yes", else: "No"}</td>
            <td>{if user.ai_flagged, do: "Yes", else: "No"}</td>
            <td>{Calendar.strftime(user.inserted_at, "%Y-%m-%d")}</td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end
end
