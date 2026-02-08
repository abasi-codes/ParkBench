defmodule ParkBenchWeb.InboxLive do
  use ParkBenchWeb, :live_view

  alias ParkBench.Messaging

  @impl true
  def mount(_params, _session, socket) do
    threads =
      Messaging.list_inbox(socket.assigns.current_user.id)
      |> decrypt_previews()

    {:ok,
     socket
     |> assign(:page_title, "Inbox")
     |> assign(:threads, threads)
     |> assign(:nav_active, :inbox)}
  end

  @impl true
  def handle_info({:new_message, _}, socket) do
    threads =
      Messaging.list_inbox(socket.assigns.current_user.id)
      |> decrypt_previews()

    {:noreply, assign(socket, :threads, threads)}
  end

  def handle_info(_, socket), do: {:noreply, socket}

  defp decrypt_previews(threads) do
    Enum.map(threads, fn item ->
      case item.last_message do
        %{encrypted_body: encrypted} when is_binary(encrypted) ->
          preview = Messaging.decrypt_message(encrypted)
          put_in(item, [:last_message, Access.key(:body)], preview)

        _ ->
          item
      end
    end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="messages-page">
      <div class="messages-page-header">
        <h1>Inbox</h1>
        <a href="/inbox/compose" class="btn btn-blue">+ Compose Message</a>
      </div>

      <div :if={@threads == []} class="empty-state">
        <div class="empty-state-icon">&#x2709;</div>
        <div class="empty-state-title">Your inbox is empty</div>
        <div class="empty-state-text">Start a conversation with one of your friends!</div>
        <a href="/inbox/compose" class="btn btn-blue">Compose Message</a>
      </div>

      <div :if={@threads != []} class="inbox-table">
        <div class="inbox-header">
          <div class="inbox-header-participants">From</div>
          <div class="inbox-header-subject">Subject</div>
          <div class="inbox-header-time">Date</div>
        </div>

        <a
          :for={%{thread: thread, other_users: users, last_message: last, unread: unread} <- @threads}
          href={"/inbox/thread/#{thread.id}"}
          class={"inbox-row #{if unread, do: "unread"}"}
        >
          <div class="inbox-row-participants">
            <.profile_thumbnail :if={List.first(users)} user={List.first(users)} size={20} />
            <span class="inbox-row-participants-names">
              {Enum.map_join(users, ", ", & &1.display_name)}
            </span>
          </div>
          <div class="inbox-row-subject">
            <div class="inbox-row-subject-text">{thread.subject || "(no subject)"}</div>
            <div :if={last && last.body} class="inbox-row-preview">
              {String.slice(last.body || "", 0, 80)}
            </div>
          </div>
          <div class="inbox-row-time">
            {format_time(thread.last_message_at || thread.inserted_at)}
          </div>
        </a>
      </div>
    </div>
    """
  end
end
