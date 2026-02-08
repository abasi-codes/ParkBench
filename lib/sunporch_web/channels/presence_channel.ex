defmodule SunporchWeb.PresenceChannel do
  use SunporchWeb, :channel

  alias SunporchWeb.Presence
  alias Sunporch.Social
  alias Sunporch.Messaging

  require Logger

  @impl true
  def join("presence:lobby", _payload, socket) do
    send(self(), :after_join)
    {:ok, socket}
  end

  @impl true
  def handle_in("open_chat", %{"friend_id" => friend_id}, socket) do
    user = socket.assigns.current_user

    case Messaging.get_or_create_chat_thread(user.id, friend_id) do
      {:ok, thread} ->
        {:reply, {:ok, %{thread_id: thread.id}}, socket}

      {:error, reason} ->
        {:reply, {:error, %{reason: to_string(reason)}}, socket}
    end
  end

  @impl true
  def handle_in("get_friends", _payload, socket) do
    user = socket.assigns.current_user
    friends = Social.list_friends(user.id)

    friend_data =
      Enum.map(friends, fn f ->
        %{
          id: f.id,
          display_name: f.display_name,
          slug: f.slug,
          avatar_url: get_avatar_url(f.id)
        }
      end)

    {:reply, {:ok, %{friends: friend_data}}, socket}
  end

  @impl true
  def handle_info(:after_join, socket) do
    user = socket.assigns.current_user

    case Presence.track(socket, user.id, %{
           display_name: user.display_name,
           online_at: System.system_time(:second)
         }) do
      {:ok, _} -> :ok
      {:error, reason} ->
        Logger.error("Failed to track presence: #{inspect(reason)}")
    end

    push(socket, "presence_state", Presence.list(socket))
    {:noreply, socket}
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  defp get_avatar_url(user_id) do
    case Sunporch.Accounts.get_current_profile_photo(user_id) do
      nil -> nil
      photo -> photo.thumb_50_url
    end
  end
end
