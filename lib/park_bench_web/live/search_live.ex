defmodule ParkBenchWeb.SearchLive do
  use ParkBenchWeb, :live_view

  alias ParkBench.{Accounts, Social, Privacy}

  @impl true
  def mount(params, _session, socket) do
    query = Map.get(params, "q", "")
    results = if query != "", do: search(query, socket.assigns.current_user), else: []

    {:ok,
     socket
     |> assign(:page_title, "Search")
     |> assign(:query, query)
     |> assign(:results, results)
     |> assign(:autocomplete_results, [])}
  end

  @impl true
  def handle_event("search", %{"q" => query}, socket) do
    results = search(query, socket.assigns.current_user)
    {:noreply, assign(socket, query: query, results: results)}
  end

  def handle_event("autocomplete", %{"q" => query}, socket) when byte_size(query) >= 2 do
    results = Accounts.search_users_autocomplete(query, socket.assigns.current_user.id)
    {:noreply, assign(socket, :autocomplete_results, results)}
  end

  def handle_event("autocomplete", _, socket) do
    {:noreply, assign(socket, :autocomplete_results, [])}
  end

  def handle_event("send_friend_request", %{"id" => user_id}, socket) do
    case Social.send_friend_request(socket.assigns.current_user.id, user_id) do
      {:ok, _} -> {:noreply, put_flash(socket, :info, "Friend request sent!")}
      {:error, reason} -> {:noreply, put_flash(socket, :error, "Error: #{reason}")}
    end
  end

  defp search(query, current_user) do
    Accounts.search_users(query, current_user_id: current_user.id)
    |> Enum.reject(fn user ->
      Social.blocked?(current_user.id, user.id) ||
        !Privacy.can_view_profile?(current_user.id, user.id)
    end)
    |> Enum.map(fn user ->
      %{
        user: user,
        relationship: Social.relationship_status(current_user.id, user.id),
        mutual_count: Social.count_mutual_friends(current_user.id, user.id)
      }
    end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="search-page">
      <h1>Search</h1>
      <form phx-submit="search" class="search-form">
        <input
          type="text"
          name="q"
          value={@query}
          placeholder="Search for people..."
          phx-keyup="autocomplete"
          phx-debounce="300"
          class="search-input-large"
        />
        <button type="submit" class="btn btn-blue">Search</button>
      </form>

      <div :if={@autocomplete_results != []} class="search-autocomplete">
        <a
          :for={result <- @autocomplete_results}
          href={"/profile/#{result.slug}"}
          class="search-result-item"
        >
          <span>{result.display_name}</span>
        </a>
      </div>

      <div :if={@results != [] && @query != ""} class="search-results">
        <h2>Results for "{@query}"</h2>
        <div
          :for={%{user: user, relationship: rel, mutual_count: mc} <- @results}
          class="search-result-row"
        >
          <a href={"/profile/#{user.slug}"}>
            <.profile_thumbnail user={user} size={50} />
          </a>
          <div class="search-result-info">
            <a href={"/profile/#{user.slug}"} class="search-result-name">{user.display_name}</a>
            <span :if={mc > 0} class="mutual-count">{mc} mutual friend{if mc != 1, do: "s"}</span>
          </div>
          <div class="search-result-action">
            <button
              :if={rel == :none}
              phx-click="send_friend_request"
              phx-value-id={user.id}
              class="btn btn-small btn-blue"
            >
              Add Friend
            </button>
            <span :if={rel == :friends} class="btn btn-small btn-gray">Friends</span>
            <span :if={rel == :request_sent} class="btn btn-small btn-gray">Request Sent</span>
          </div>
        </div>
      </div>

      <div :if={@results == [] && @query != ""} class="no-results">
        <p>No results found for "{@query}".</p>
      </div>
    </div>
    """
  end
end
