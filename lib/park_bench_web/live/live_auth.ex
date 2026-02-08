defmodule ParkBenchWeb.LiveAuth do
  @moduledoc "LiveView on_mount hooks for authentication"
  import Phoenix.LiveView
  import Phoenix.Component
  alias ParkBench.Accounts

  def on_mount(:ensure_authenticated, _params, session, socket) do
    case session["session_token"] do
      nil ->
        {:halt, redirect(socket, to: "/")}

      token ->
        case Accounts.get_user_by_session_token(token) do
          nil ->
            {:halt, redirect(socket, to: "/")}

          user ->
            recent_notifs = ParkBench.Notifications.list_notifications(user.id, per_page: 5)
            pending_reqs = ParkBench.Social.list_pending_requests_for(user.id)

            socket =
              socket
              |> assign(:current_user, user)
              |> assign(:unread_notifications, ParkBench.Notifications.count_unread(user.id))
              |> assign(:unread_messages, ParkBench.Messaging.count_unread(user.id))
              |> assign(
                :pending_friend_requests,
                ParkBench.Social.count_pending_requests(user.id)
              )
              |> assign(:pending_pokes, ParkBench.Social.list_pending_pokes(user.id))
              |> assign(:recent_notifications, recent_notifs)
              |> assign(:pending_requests_list, Enum.take(pending_reqs, 5))
              |> assign(:show_notif_dropdown, false)
              |> assign(:show_friends_dropdown, false)

            if connected?(socket) do
              Phoenix.PubSub.subscribe(ParkBench.PubSub, "user:#{user.id}")
            end

            socket =
              attach_hook(socket, :realtime_badges, :handle_info, fn
                {:new_notification, _}, socket ->
                  notifs =
                    ParkBench.Notifications.list_notifications(socket.assigns.current_user.id,
                      per_page: 5
                    )

                  {:cont,
                   socket
                   |> update(:unread_notifications, &(&1 + 1))
                   |> assign(:recent_notifications, notifs)
                   |> push_event("show_toast", %{message: "You have a new notification"})}

                {:new_message, _}, socket ->
                  {:cont,
                   socket
                   |> update(:unread_messages, &(&1 + 1))
                   |> push_event("show_toast", %{message: "You have a new message"})}

                {:friend_request, _}, socket ->
                  reqs =
                    ParkBench.Social.list_pending_requests_for(socket.assigns.current_user.id)

                  {:cont,
                   socket
                   |> update(:pending_friend_requests, &(&1 + 1))
                   |> assign(:pending_requests_list, Enum.take(reqs, 5))
                   |> push_event("show_toast", %{message: "New friend request!"})}

                {:friend_accepted, _}, socket ->
                  {:cont,
                   socket
                   |> update(:pending_friend_requests, &max(0, &1 - 1))
                   |> push_event("show_toast", %{message: "Friend request accepted!"})}

                {:poked, _}, socket ->
                  pokes = ParkBench.Social.list_pending_pokes(socket.assigns.current_user.id)

                  {:cont,
                   socket
                   |> assign(:pending_pokes, pokes)
                   |> push_event("show_toast", %{message: "Someone poked you!"})}

                _, socket ->
                  {:cont, socket}
              end)

            socket =
              attach_hook(socket, :dropdown_events, :handle_event, fn
                "toggle_notif_dropdown", _, socket ->
                  {:halt,
                   {:noreply,
                    socket
                    |> update(:show_notif_dropdown, &(!&1))
                    |> assign(:show_friends_dropdown, false)}}

                "toggle_friends_dropdown", _, socket ->
                  {:halt,
                   {:noreply,
                    socket
                    |> update(:show_friends_dropdown, &(!&1))
                    |> assign(:show_notif_dropdown, false)}}

                "close_dropdowns", _, socket ->
                  {:halt,
                   {:noreply,
                    socket
                    |> assign(:show_notif_dropdown, false)
                    |> assign(:show_friends_dropdown, false)}}

                "accept_request_dropdown", %{"id" => request_id}, socket ->
                  ParkBench.Social.accept_friend_request(
                    request_id,
                    socket.assigns.current_user.id
                  )

                  reqs =
                    ParkBench.Social.list_pending_requests_for(socket.assigns.current_user.id)

                  count = ParkBench.Social.count_pending_requests(socket.assigns.current_user.id)

                  {:halt,
                   {:noreply,
                    socket
                    |> assign(:pending_requests_list, Enum.take(reqs, 5))
                    |> assign(:pending_friend_requests, count)}}

                "ignore_request_dropdown", %{"id" => request_id}, socket ->
                  ParkBench.Social.reject_friend_request(
                    request_id,
                    socket.assigns.current_user.id
                  )

                  reqs =
                    ParkBench.Social.list_pending_requests_for(socket.assigns.current_user.id)

                  count = ParkBench.Social.count_pending_requests(socket.assigns.current_user.id)

                  {:halt,
                   {:noreply,
                    socket
                    |> assign(:pending_requests_list, Enum.take(reqs, 5))
                    |> assign(:pending_friend_requests, count)}}

                _, _, socket ->
                  {:cont, socket}
              end)

            {:cont, socket}
        end
    end
  end

  def on_mount(:ensure_admin, _params, session, socket) do
    case session["session_token"] do
      nil ->
        {:halt, redirect(socket, to: "/")}

      token ->
        case Accounts.get_user_by_session_token(token) do
          %{role: role} = user when role in ["admin", "moderator"] ->
            {:cont,
             socket
             |> assign(:current_user, user)
             |> assign(:unread_notifications, ParkBench.Notifications.count_unread(user.id))
             |> assign(:unread_messages, ParkBench.Messaging.count_unread(user.id))
             |> assign(:pending_friend_requests, ParkBench.Social.count_pending_requests(user.id))
             |> assign(:pending_pokes, ParkBench.Social.list_pending_pokes(user.id))
             |> assign(
               :recent_notifications,
               ParkBench.Notifications.list_notifications(user.id, per_page: 5)
             )
             |> assign(
               :pending_requests_list,
               ParkBench.Social.list_pending_requests_for(user.id) |> Enum.take(5)
             )
             |> assign(:show_notif_dropdown, false)
             |> assign(:show_friends_dropdown, false)}

          _ ->
            {:halt, redirect(socket, to: "/feed")}
        end
    end
  end
end
