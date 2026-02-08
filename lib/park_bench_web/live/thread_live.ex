defmodule ParkBenchWeb.ThreadLive do
  use ParkBenchWeb, :live_view

  alias ParkBench.Messaging

  @impl true
  def mount(%{"id" => thread_id}, _session, socket) do
    case Messaging.get_thread(thread_id, socket.assigns.current_user.id) do
      {:ok, %{thread: thread, messages: messages, other_users: others}} ->
        if connected?(socket) do
          Phoenix.PubSub.subscribe(ParkBench.PubSub, "thread:#{thread_id}")
        end

        {:ok,
         socket
         |> assign(:page_title, thread.subject || "Message")
         |> assign(:thread, thread)
         |> assign(:messages, messages)
         |> assign(:other_users, others)
         |> assign(:reply_body, "")}

      {:error, _} ->
        {:ok, push_navigate(socket, to: "/inbox") |> put_flash(:error, "Thread not found.")}
    end
  end

  @impl true
  def handle_event("send_reply", %{"body" => body}, socket) do
    case Messaging.reply_to_thread(socket.assigns.thread.id, socket.assigns.current_user.id, body) do
      {:ok, _} ->
        {:ok, %{messages: messages}} =
          Messaging.get_thread(socket.assigns.thread.id, socket.assigns.current_user.id)

        {:noreply, assign(socket, messages: messages, reply_body: "")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not send reply.")}
    end
  end

  @impl true
  def handle_info({:new_message, _}, socket) do
    {:ok, %{messages: messages}} =
      Messaging.get_thread(socket.assigns.thread.id, socket.assigns.current_user.id)

    {:noreply, assign(socket, :messages, messages)}
  end

  def handle_info(_, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <div class="thread-view">
      <div class="thread-header">
        <div>
          <div class="thread-subject">{@thread.subject || "Message"}</div>
          <div class="thread-participants">
            With: {Enum.map_join(@other_users, ", ", & &1.display_name)}
          </div>
        </div>
        <div class="thread-actions">
          <a href="/inbox" class="btn btn-small btn-gray">&laquo; Back to Inbox</a>
        </div>
      </div>

      <div class="thread-messages">
        <div
          :for={msg <- @messages}
          class={"message-bubble #{if msg.sender_id == @current_user.id, do: "own"}"}
        >
          <.profile_thumbnail user={msg.sender} size={32} />
          <div class="message-bubble-content">
            <div class="message-bubble-header">
              <span class="message-bubble-sender">{msg.sender.display_name}</span>
              <span class="message-bubble-time">{format_time(msg.inserted_at)}</span>
            </div>
            <div class="message-bubble-body">{msg.body}</div>
          </div>
        </div>
      </div>

      <div class="thread-reply">
        <form phx-submit="send_reply">
          <div class="thread-reply-label">Reply</div>
          <textarea
            name="body"
            class="form-textarea"
            rows="4"
            placeholder="Write a reply..."
            maxlength="5000"
          >{@reply_body}</textarea>
          <div class="thread-reply-actions">
            <button type="submit" class="btn btn-blue">Reply</button>
          </div>
        </form>
      </div>
    </div>
    """
  end
end
