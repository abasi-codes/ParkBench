defmodule SunporchWeb.ComposeMessageLive do
  use SunporchWeb, :live_view

  alias Sunporch.{Messaging, Accounts}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Compose Message")
     |> assign(:recipient_query, "")
     |> assign(:recipient_results, [])
     |> assign(:selected_recipient, nil)
     |> assign(:subject, "")
     |> assign(:body, "")}
  end

  @impl true
  def handle_event("search_recipient", %{"q" => query}, socket) when byte_size(query) >= 2 do
    results = Accounts.search_users_autocomplete(query, socket.assigns.current_user.id)
    {:noreply, assign(socket, recipient_query: query, recipient_results: results)}
  end

  def handle_event("search_recipient", _, socket) do
    {:noreply, assign(socket, :recipient_results, [])}
  end

  def handle_event("select_recipient", %{"id" => id}, socket) do
    user = Accounts.get_user!(id)
    {:noreply, assign(socket, selected_recipient: user, recipient_results: [], recipient_query: user.display_name)}
  end

  def handle_event("send_message", %{"subject" => subject, "body" => body}, socket) do
    recipient = socket.assigns.selected_recipient

    if is_nil(recipient) do
      {:noreply, put_flash(socket, :error, "Please select a recipient.")}
    else
      case Messaging.create_thread(socket.assigns.current_user.id, recipient.id, subject, body) do
        {:ok, %{thread: thread}} ->
          {:noreply, push_navigate(socket, to: "/inbox/thread/#{thread.id}")}
        {:error, reason} ->
          {:noreply, put_flash(socket, :error, "Could not send message: #{inspect(reason)}")}
      end
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="messages-page">
      <div class="compose-form">
        <div class="compose-form-header">New Message</div>
        <div class="compose-form-body">
          <form phx-submit="send_message">
            <div class="compose-field">
              <label>To:</label>
              <div style="flex:1;position:relative;">
                <div :if={@selected_recipient} class="compose-selected-recipient">
                  <.profile_thumbnail user={@selected_recipient} size={20} />
                  {@selected_recipient.display_name}
                </div>
                <input
                  :if={!@selected_recipient}
                  type="text"
                  value={@recipient_query}
                  phx-keyup="search_recipient"
                  phx-value-q={@recipient_query}
                  phx-debounce="300"
                  placeholder="Start typing a name..."
                  class="form-input"
                />
                <div :if={@recipient_results != []} class="compose-autocomplete">
                  <div
                    :for={result <- @recipient_results}
                    phx-click="select_recipient"
                    phx-value-id={result.id}
                    class="compose-autocomplete-item"
                  >
                    <.profile_thumbnail user={result} size={20} />
                    {result.display_name}
                  </div>
                </div>
              </div>
            </div>
            <div class="compose-field">
              <label>Subject:</label>
              <input type="text" name="subject" value={@subject} maxlength="500" class="form-input" />
            </div>
            <div class="compose-field">
              <label>Message:</label>
              <textarea name="body" rows="8" maxlength="5000" class="form-textarea compose-body-textarea">{@body}</textarea>
            </div>
            <div class="compose-form-footer" style="border:none;background:none;padding:8px 0 0;">
              <button type="submit" class="btn btn-blue">Send</button>
              <a href="/inbox" class="btn btn-gray">Cancel</a>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end
end
