defmodule SunporchWeb.NotificationsLive do
  use SunporchWeb, :live_view

  alias Sunporch.Notifications

  @impl true
  def mount(_params, _session, socket) do
    notifications = Notifications.list_notifications(socket.assigns.current_user.id)

    {:ok,
     socket
     |> assign(:page_title, "Notifications")
     |> assign(:notifications, notifications)}
  end

  @impl true
  def handle_event("mark_read", %{"id" => id}, socket) do
    Notifications.mark_read(id, socket.assigns.current_user.id)
    notifications = Notifications.list_notifications(socket.assigns.current_user.id)
    unread = Notifications.count_unread(socket.assigns.current_user.id)
    {:noreply, assign(socket, notifications: notifications, unread_notifications: unread)}
  end

  def handle_event("mark_all_read", _, socket) do
    Notifications.mark_all_read(socket.assigns.current_user.id)
    notifications = Notifications.list_notifications(socket.assigns.current_user.id)
    {:noreply, assign(socket, notifications: notifications, unread_notifications: 0)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="notifications-page">
      <div class="notifications-header">
        <h1>Notifications</h1>
        <button phx-click="mark_all_read" class="btn btn-small btn-gray">Mark All as Read</button>
      </div>

      <div :if={@notifications == []} class="empty-state">
        <div class="empty-state-icon">&#x2600;</div>
        <div class="empty-state-title">All caught up!</div>
        <div class="empty-state-text">You have no notifications right now. Check back later!</div>
      </div>

      <div :for={notif <- @notifications}
           class={"notification-row #{if is_nil(notif.read_at), do: "unread"}"}
           phx-click="mark_read" phx-value-id={notif.id}>
        <.profile_thumbnail user={notif.actor} size={32} />
        <div class="notification-text">
          <span>{notification_text(notif)}</span>
          <span class="notification-time">{format_time(notif.inserted_at)}</span>
        </div>
      </div>
    </div>
    """
  end

  defp notification_text(notif) do
    name = notif.actor.display_name
    case notif.type do
      "friend_request" -> "#{name} sent you a friend request."
      "friend_accept" -> "#{name} accepted your friend request."
      "wall_post" -> "#{name} wrote on your wall."
      "wall_comment" -> "#{name} commented on a post on your wall."
      "post_comment" -> "#{name} commented on your post."
      "new_message" -> "#{name} sent you a message."
      "poke" -> "#{name} poked you."
      "photo_tag" -> "#{name} tagged you in a photo."
      _ -> "#{name} interacted with you."
    end
  end
end
