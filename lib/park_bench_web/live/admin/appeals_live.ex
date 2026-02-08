defmodule ParkBenchWeb.Admin.AppealsLive do
  use ParkBenchWeb, :live_view

  alias ParkBench.AIDetection

  @impl true
  def mount(_params, _session, socket) do
    appeals = AIDetection.list_pending_appeals()

    {:ok,
     socket
     |> assign(:page_title, "AI Detection Appeals")
     |> assign(:appeals, appeals)}
  end

  @impl true
  def handle_event("approve", %{"id" => id}, socket) do
    AIDetection.review_appeal(id, socket.assigns.current_user.id, "approved")
    appeals = AIDetection.list_pending_appeals()
    {:noreply, assign(socket, :appeals, appeals) |> put_flash(:info, "Appeal approved.")}
  end

  def handle_event("deny", %{"id" => id}, socket) do
    AIDetection.review_appeal(id, socket.assigns.current_user.id, "denied")
    appeals = AIDetection.list_pending_appeals()
    {:noreply, assign(socket, :appeals, appeals) |> put_flash(:info, "Appeal denied.")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="admin-page">
      <h1>AI Detection Appeals</h1>
      <div :if={@appeals == []} class="empty-state">
        <p>No pending appeals.</p>
      </div>
      <div :for={appeal <- @appeals} class="appeal-card">
        <div class="appeal-header">
          <strong>{appeal.user.display_name}</strong>
          <span class="appeal-time">{format_time(appeal.inserted_at)}</span>
        </div>
        <div class="appeal-body">
          <p><strong>Explanation:</strong> {appeal.explanation}</p>
          <p :if={appeal.tools_used}><strong>Tools used:</strong> {appeal.tools_used}</p>
          <p><strong>Detection score:</strong> {appeal.detection_result.score}</p>
          <p><strong>Content type:</strong> {appeal.detection_result.content_type}</p>
        </div>
        <div class="appeal-actions">
          <button phx-click="approve" phx-value-id={appeal.id} class="btn btn-green">Approve</button>
          <button phx-click="deny" phx-value-id={appeal.id} class="btn btn-small btn-gray">
            Deny
          </button>
        </div>
      </div>
    </div>
    """
  end
end
