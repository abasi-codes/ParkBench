defmodule ParkBenchWeb.FriendRequestsLive do
  use ParkBenchWeb, :live_view

  alias ParkBench.Social

  @impl true
  def mount(_params, _session, socket) do
    requests = Social.list_pending_requests_for(socket.assigns.current_user.id)
    sent = Social.list_sent_requests(socket.assigns.current_user.id)

    {:ok,
     socket
     |> assign(:page_title, "Friend Requests")
     |> assign(:requests, requests)
     |> assign(:sent_requests, sent)}
  end

  @impl true
  def handle_event("accept", %{"id" => id}, socket) do
    Social.accept_friend_request(id, socket.assigns.current_user.id)
    requests = Social.list_pending_requests_for(socket.assigns.current_user.id)
    count = Social.count_pending_requests(socket.assigns.current_user.id)
    {:noreply, assign(socket, requests: requests, pending_friend_requests: count)}
  end

  def handle_event("reject", %{"id" => id}, socket) do
    Social.reject_friend_request(id, socket.assigns.current_user.id)
    requests = Social.list_pending_requests_for(socket.assigns.current_user.id)
    count = Social.count_pending_requests(socket.assigns.current_user.id)
    {:noreply, assign(socket, requests: requests, pending_friend_requests: count)}
  end

  def handle_event("cancel", %{"id" => id}, socket) do
    Social.cancel_friend_request(id, socket.assigns.current_user.id)
    sent = Social.list_sent_requests(socket.assigns.current_user.id)
    {:noreply, assign(socket, :sent_requests, sent)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="friend-requests-page">
      <h1>Friend Requests</h1>

      <div :if={@requests != []} class="requests-section">
        <h2>Received ({length(@requests)})</h2>
        <div :for={%{request: req, sender: sender} <- @requests} class="request-row">
          <a href={"/profile/#{sender.slug}"}>
            <.profile_thumbnail user={sender} size={50} />
          </a>
          <div class="request-info">
            <a href={"/profile/#{sender.slug}"}>{sender.display_name}</a>
          </div>
          <div class="request-actions">
            <button phx-click="accept" phx-value-id={req.id} class="btn btn-small btn-blue">
              Confirm
            </button>
            <button phx-click="reject" phx-value-id={req.id} class="btn btn-small btn-gray">
              Ignore
            </button>
          </div>
        </div>
      </div>

      <div :if={@requests == []} class="no-requests">
        <p>No pending friend requests.</p>
      </div>

      <div :if={@sent_requests != []} class="sent-section">
        <h2>Sent Requests</h2>
        <div :for={%{request: req, receiver: receiver} <- @sent_requests} class="request-row">
          <a href={"/profile/#{receiver.slug}"}>
            <.profile_thumbnail user={receiver} size={50} />
          </a>
          <div class="request-info">
            <a href={"/profile/#{receiver.slug}"}>{receiver.display_name}</a>
            <span class="text-light">-- Pending</span>
          </div>
          <div class="request-actions">
            <button phx-click="cancel" phx-value-id={req.id} class="btn btn-small btn-gray">
              Cancel
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
