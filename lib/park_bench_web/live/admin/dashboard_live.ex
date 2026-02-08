defmodule ParkBenchWeb.Admin.DashboardLive do
  use ParkBenchWeb, :live_view

  alias ParkBench.AIDetection

  @impl true
  def mount(_params, _session, socket) do
    stats = AIDetection.detection_stats()

    {:ok,
     socket
     |> assign(:page_title, "Admin Dashboard")
     |> assign(:stats, stats)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="admin-page">
      <h1>Admin Dashboard</h1>
      <div class="admin-stats">
        <div class="stat-card">
          <h3>AI Detection</h3>
          <p>Total scans: {@stats.total}</p>
          <p>Pending: {@stats.pending}</p>
          <p>Approved: {@stats.approved}</p>
          <p>Rejected: {@stats.rejected}</p>
          <p>Appeals pending: {@stats.appeals_pending}</p>
        </div>
      </div>
      <nav class="admin-nav">
        <a href="/admin/users" class="btn btn-gray">Manage Users</a>
        <a href="/admin/moderation" class="btn btn-gray">Moderation Queue</a>
        <a href="/admin/appeals" class="btn btn-gray">Appeals</a>
        <a href="/admin/ai-thresholds" class="btn btn-gray">AI Thresholds</a>
      </nav>
    </div>
    """
  end
end
