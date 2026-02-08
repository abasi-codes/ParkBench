defmodule ParkBenchWeb.FriendsListLive do
  use ParkBenchWeb, :live_view

  alias ParkBench.{Accounts, Social, Privacy}

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    profile_user = Accounts.get_user_by_slug(slug)
    current_user = socket.assigns.current_user

    cond do
      is_nil(profile_user) ->
        {:ok, push_navigate(socket, to: "/feed") |> put_flash(:error, "User not found.")}

      Social.blocked?(current_user.id, profile_user.id) ->
        {:ok, push_navigate(socket, to: "/feed") |> put_flash(:error, "User not found.")}

      true ->
        privacy = Privacy.get_privacy_settings(profile_user.id)

        can_view =
          Privacy.visible_to?(privacy.friend_list_visibility, current_user.id, profile_user.id)

        if can_view do
          friends = Social.list_friends(profile_user.id)

          grouped =
            friends |> Enum.group_by(&String.first(&1.display_name)) |> Enum.sort_by(&elem(&1, 0))

          {:ok,
           socket
           |> assign(:page_title, "#{profile_user.display_name}'s Friends")
           |> assign(:profile_user, profile_user)
           |> assign(:grouped_friends, grouped)
           |> assign(:total, length(friends))
           |> assign(:private, false)}
        else
          {:ok,
           socket
           |> assign(:page_title, "#{profile_user.display_name}'s Friends")
           |> assign(:profile_user, profile_user)
           |> assign(:grouped_friends, [])
           |> assign(:total, 0)
           |> assign(:private, true)}
        end
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="friends-list-page">
      <h1>{@profile_user.display_name}'s Friends ({@total})</h1>

      <div :if={@private} class="content-box-padded">
        <p>{@profile_user.display_name}'s friend list is private.</p>
      </div>

      <div :for={{letter, friends} <- @grouped_friends} class="friends-letter-group">
        <h2 class="letter-header">{letter}</h2>
        <div class="friends-grid-full">
          <a :for={friend <- friends} href={"/profile/#{friend.slug}"} class="friend-card">
            <.profile_thumbnail user={friend} size={50} />
            <span>{friend.display_name}</span>
          </a>
        </div>
      </div>
    </div>
    """
  end
end
