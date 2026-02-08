defmodule ParkBenchWeb.Admin.ModerationLive do
  use ParkBenchWeb, :live_view

  import Ecto.Query
  alias ParkBench.Repo
  alias ParkBench.AIDetection
  alias ParkBench.AIDetection.DetectionResult

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Moderation Queue", results: load_results())}
  end

  @impl true
  def handle_event("approve", %{"id" => id}, socket) do
    AIDetection.update_detection_status(id, "approved")
    {:noreply, assign(socket, :results, load_results()) |> put_flash(:info, "Content approved.")}
  end

  def handle_event("reject", %{"id" => id}, socket) do
    AIDetection.update_detection_status(id, "hard_rejected")
    {:noreply, assign(socket, :results, load_results()) |> put_flash(:info, "Content rejected.")}
  end

  defp load_results do
    DetectionResult
    |> where([r], r.status == "needs_review")
    |> order_by([r], asc: r.inserted_at)
    |> limit(50)
    |> preload(:user)
    |> Repo.all()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="admin-page">
      <h1>Moderation Queue</h1>
      <div :if={@results == []} class="empty-state">
        <p>No content pending review.</p>
      </div>
      <table :if={@results != []} class="admin-table">
        <thead>
          <tr>
            <th>User</th>
            <th>Type</th>
            <th>Score</th>
            <th>Provider</th>
            <th>Date</th>
            <th>Actions</th>
          </tr>
        </thead>
        <tbody>
          <tr :for={result <- @results}>
            <td>{result.user.display_name}</td>
            <td>{result.content_type}</td>
            <td>{Float.round(result.score, 3)}</td>
            <td>{result.provider}</td>
            <td>{Calendar.strftime(result.inserted_at, "%Y-%m-%d %H:%M")}</td>
            <td>
              <button phx-click="approve" phx-value-id={result.id} class="btn btn-small btn-green">
                Approve
              </button>
              <button
                phx-click="reject"
                phx-value-id={result.id}
                class="btn btn-small"
                style="background:#cc0000;color:#fff;"
              >
                Reject
              </button>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end
end
