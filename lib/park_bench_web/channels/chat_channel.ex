defmodule ParkBenchWeb.ChatChannel do
  use ParkBenchWeb, :channel

  alias ParkBench.Messaging

  @impl true
  def join("chat:" <> thread_id, _payload, socket) do
    user = socket.assigns.current_user

    case Messaging.get_thread(thread_id, user.id) do
      {:ok, %{messages: messages, other_users: other_users}} ->
        # Subscribe to PubSub for this thread
        Phoenix.PubSub.subscribe(ParkBench.PubSub, "thread:#{thread_id}")

        socket =
          socket
          |> assign(:thread_id, thread_id)

        serialized_messages =
          Enum.map(messages, fn msg ->
            %{
              id: msg.id,
              body: msg.body,
              sender_id: msg.sender_id,
              sender_name: msg.sender.display_name,
              inserted_at: DateTime.to_iso8601(msg.inserted_at)
            }
          end)

        other_user = List.first(other_users)

        {:ok,
         %{
           messages: serialized_messages,
           other_user: other_user && %{id: other_user.id, display_name: other_user.display_name}
         }, socket}

      {:error, _reason} ->
        {:error, %{reason: "unauthorized"}}
    end
  end

  @impl true
  def handle_in("new_message", %{"body" => body}, socket) do
    user = socket.assigns.current_user
    thread_id = socket.assigns.thread_id

    case Messaging.send_chat_message(thread_id, user.id, body) do
      {:ok, _message} ->
        {:reply, :ok, socket}

      {:error, :rate_limited} ->
        {:reply, {:error, %{reason: "rate_limited"}}, socket}

      {:error, %Ecto.Changeset{}} ->
        {:reply, {:error, %{reason: "invalid_message"}}, socket}

      {:error, reason} when is_atom(reason) ->
        {:reply, {:error, %{reason: to_string(reason)}}, socket}

      {:error, _} ->
        {:reply, {:error, %{reason: "unknown_error"}}, socket}
    end
  end

  def handle_in("typing", _payload, socket) do
    user = socket.assigns.current_user

    broadcast_from(socket, "typing", %{
      user_id: user.id,
      display_name: user.display_name
    })

    {:noreply, socket}
  end

  def handle_in("stop_typing", _payload, socket) do
    user = socket.assigns.current_user
    broadcast_from(socket, "stop_typing", %{user_id: user.id})
    {:noreply, socket}
  end

  def handle_in("mark_read", _payload, socket) do
    user = socket.assigns.current_user
    thread_id = socket.assigns.thread_id

    case Messaging.mark_chat_read(thread_id, user.id) do
      {:ok, _} ->
        broadcast_from(socket, "read_receipt", %{user_id: user.id})
        {:reply, :ok, socket}

      {:error, _} ->
        {:reply, {:error, %{reason: "failed"}}, socket}
    end
  end

  @impl true
  def handle_info({:new_message, message}, socket) do
    # Decrypt the message body for sending to client
    decrypted_body = Messaging.decrypt_message(message.encrypted_body)

    sender = ParkBench.Accounts.get_user!(message.sender_id)

    push(socket, "new_message", %{
      id: message.id,
      body: decrypted_body,
      sender_id: message.sender_id,
      sender_name: sender.display_name,
      inserted_at: DateTime.to_iso8601(message.inserted_at)
    })

    {:noreply, socket}
  end

  def handle_info(_msg, socket), do: {:noreply, socket}
end
