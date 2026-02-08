defmodule ParkBench.Social do
  @moduledoc "Friend system, pokes, and friend suggestions"

  import Ecto.Query
  alias ParkBench.Repo
  alias ParkBench.Social.{Friendship, FriendRequest, Poke}
  alias ParkBench.Privacy.Block
  alias ParkBench.Accounts.User
  alias ParkBench.RateLimiter

  # === Friendships ===

  def friends?(user_id, other_id) when is_binary(user_id) and is_binary(other_id) do
    {low, high} = canonical_pair(user_id, other_id)
    Repo.exists?(from f in Friendship, where: f.user_id == ^low and f.friend_id == ^high)
  end

  def list_friends(user_id) do
    friends_query(user_id)
    |> Repo.all()
  end

  def list_friends_paginated(user_id, page, per_page \\ 20) do
    friends_query(user_id)
    |> order_by([u], u.display_name)
    |> offset(^((page - 1) * per_page))
    |> limit(^per_page)
    |> Repo.all()
  end

  def count_friends(user_id) do
    from(f in Friendship,
      where: f.user_id == ^user_id or f.friend_id == ^user_id
    )
    |> Repo.aggregate(:count)
  end

  def mutual_friends(user_id, other_id) do
    my_friends = friend_ids_list(user_id)
    their_friends = friend_ids_list(other_id)

    mutual_ids =
      MapSet.intersection(MapSet.new(my_friends), MapSet.new(their_friends)) |> MapSet.to_list()

    if mutual_ids == [] do
      []
    else
      from(u in User, where: u.id in ^mutual_ids) |> Repo.all()
    end
  end

  def count_mutual_friends(user_id, other_id) do
    my_friends = friend_ids_list(user_id)
    their_friends = friend_ids_list(other_id)
    MapSet.intersection(MapSet.new(my_friends), MapSet.new(their_friends)) |> MapSet.size()
  end

  defp friends_query(user_id) do
    from(u in User,
      join: f in Friendship,
      on:
        (f.user_id == ^user_id and f.friend_id == u.id) or
          (f.friend_id == ^user_id and f.user_id == u.id)
    )
  end

  defp friend_ids_list(user_id) do
    as_user =
      from(f in Friendship, where: f.user_id == ^user_id, select: f.friend_id) |> Repo.all()

    as_friend =
      from(f in Friendship, where: f.friend_id == ^user_id, select: f.user_id) |> Repo.all()

    Enum.uniq(as_user ++ as_friend)
  end

  defp canonical_pair(id1, id2) do
    if id1 < id2, do: {id1, id2}, else: {id2, id1}
  end

  # === Friend Requests ===

  def send_friend_request(sender_id, receiver_id) do
    cond do
      sender_id == receiver_id ->
        {:error, :cannot_friend_self}

      friends?(sender_id, receiver_id) ->
        {:error, :already_friends}

      blocked?(sender_id, receiver_id) || blocked?(receiver_id, sender_id) ->
        {:error, :blocked}

      pending_request?(sender_id, receiver_id) ->
        {:error, :already_requested}

      RateLimiter.check(sender_id, :send_friend_request) != :ok ->
        {:error, :rate_limited}

      pending_request?(receiver_id, sender_id) ->
        # They already sent us a request — auto-accept
        accept_friend_request_by_users(receiver_id, sender_id)

      true ->
        %FriendRequest{}
        |> FriendRequest.changeset(%{sender_id: sender_id, receiver_id: receiver_id})
        |> Repo.insert()
        |> case do
          {:ok, request} ->
            Phoenix.PubSub.broadcast(
              ParkBench.PubSub,
              "user:#{receiver_id}",
              {:friend_request, request}
            )

            {:ok, request}

          error ->
            error
        end
    end
  end

  def accept_friend_request(request_id, receiver_id) do
    request = Repo.get!(FriendRequest, request_id)

    if request.receiver_id != receiver_id do
      {:error, :unauthorized}
    else
      accept_friend_request_by_users(request.sender_id, request.receiver_id)
    end
  end

  defp accept_friend_request_by_users(sender_id, receiver_id) do
    {low, high} = canonical_pair(sender_id, receiver_id)

    Repo.transaction(fn ->
      # Update request status
      from(fr in FriendRequest,
        where:
          fr.sender_id == ^sender_id and fr.receiver_id == ^receiver_id and fr.status == "pending"
      )
      |> Repo.update_all(
        set: [status: "accepted", updated_at: DateTime.utc_now() |> DateTime.truncate(:second)]
      )

      # Create friendship
      %Friendship{}
      |> Friendship.changeset(%{user_id: low, friend_id: high})
      |> Repo.insert!()

      # Create feed items for both users
      ParkBench.Timeline.create_feed_item(%{
        user_id: sender_id,
        item_type: "new_friendship",
        content_id: receiver_id
      })

      ParkBench.Timeline.create_feed_item(%{
        user_id: receiver_id,
        item_type: "new_friendship",
        content_id: sender_id
      })

      # Broadcast
      Phoenix.PubSub.broadcast(
        ParkBench.PubSub,
        "user:#{sender_id}",
        {:friend_accepted, receiver_id}
      )
    end)
  end

  def reject_friend_request(request_id, receiver_id) do
    request = Repo.get!(FriendRequest, request_id)

    if request.receiver_id != receiver_id do
      {:error, :unauthorized}
    else
      request
      |> FriendRequest.status_changeset(%{status: "rejected"})
      |> Repo.update()
    end
  end

  def cancel_friend_request(request_id, sender_id) do
    request = Repo.get!(FriendRequest, request_id)

    if request.sender_id != sender_id do
      {:error, :unauthorized}
    else
      request
      |> FriendRequest.status_changeset(%{status: "cancelled"})
      |> Repo.update()
    end
  end

  def list_pending_requests_for(user_id) do
    FriendRequest
    |> where([fr], fr.receiver_id == ^user_id and fr.status == "pending")
    |> join(:inner, [fr], u in User, on: u.id == fr.sender_id)
    |> select([fr, u], %{request: fr, sender: u})
    |> order_by([fr, _], desc: fr.inserted_at)
    |> Repo.all()
  end

  def list_sent_requests(user_id) do
    FriendRequest
    |> where([fr], fr.sender_id == ^user_id and fr.status == "pending")
    |> join(:inner, [fr], u in User, on: u.id == fr.receiver_id)
    |> select([fr, u], %{request: fr, receiver: u})
    |> order_by([fr, _], desc: fr.inserted_at)
    |> Repo.all()
  end

  def count_pending_requests(user_id) do
    FriendRequest
    |> where([fr], fr.receiver_id == ^user_id and fr.status == "pending")
    |> Repo.aggregate(:count)
  end

  defp pending_request?(sender_id, receiver_id) do
    Repo.exists?(
      from fr in FriendRequest,
        where:
          fr.sender_id == ^sender_id and fr.receiver_id == ^receiver_id and fr.status == "pending"
    )
  end

  # === Unfriend ===

  def unfriend(user_id, friend_id) do
    {low, high} = canonical_pair(user_id, friend_id)

    from(f in Friendship, where: f.user_id == ^low and f.friend_id == ^high)
    |> Repo.delete_all()

    :ok
  end

  # === People You May Know ===

  def people_you_may_know(user_id, limit \\ 10) do
    my_friend_ids = friend_ids_list(user_id)
    blocked_ids = blocked_user_ids(user_id)
    exclude_ids = [user_id | my_friend_ids] ++ blocked_ids

    if my_friend_ids == [] do
      []
    else
      # Find users who are friends with my friends but not my friends
      from(u in User,
        join: f in Friendship,
        on: f.user_id == u.id or f.friend_id == u.id,
        where: u.id not in ^exclude_ids,
        where:
          (f.user_id in ^my_friend_ids and f.friend_id == u.id) or
            (f.friend_id in ^my_friend_ids and f.user_id == u.id),
        group_by: [u.id],
        order_by: [desc: count(u.id)],
        limit: ^limit,
        select: {u, count(u.id)}
      )
      |> Repo.all()
      |> Enum.map(fn {user, mutual_count} -> %{user: user, mutual_count: mutual_count} end)
    end
  end

  # === Pokes ===

  def poke(poker_id, pokee_id) do
    cond do
      poker_id == pokee_id ->
        {:error, :cannot_poke_self}

      !friends?(poker_id, pokee_id) ->
        {:error, :not_friends}

      blocked?(poker_id, pokee_id) ->
        {:error, :blocked}

      RateLimiter.check(poker_id, :poke) != :ok ->
        {:error, :rate_limited}

      true ->
        %Poke{}
        |> Poke.changeset(%{poker_id: poker_id, pokee_id: pokee_id})
        |> Repo.insert(on_conflict: :nothing)
        |> case do
          {:ok, poke} ->
            Phoenix.PubSub.broadcast(ParkBench.PubSub, "user:#{pokee_id}", {:poked, poker_id})
            {:ok, poke}

          error ->
            error
        end
    end
  end

  def poke_back(pokee_id, poker_id) do
    # Delete the incoming poke, then create reverse
    Repo.transaction(fn ->
      from(p in Poke, where: p.poker_id == ^poker_id and p.pokee_id == ^pokee_id)
      |> Repo.delete_all()

      %Poke{}
      |> Poke.changeset(%{poker_id: pokee_id, pokee_id: poker_id})
      |> Repo.insert!()
    end)
  end

  def dismiss_poke(poker_id, pokee_id) do
    from(p in Poke, where: p.poker_id == ^poker_id and p.pokee_id == ^pokee_id)
    |> Repo.delete_all()

    :ok
  end

  def active_poke?(poker_id, pokee_id) do
    Repo.exists?(
      from p in Poke,
        where: p.poker_id == ^poker_id and p.pokee_id == ^pokee_id
    )
  end

  def list_pending_pokes(user_id) do
    Poke
    |> where([p], p.pokee_id == ^user_id)
    |> join(:inner, [p], u in User, on: u.id == p.poker_id)
    |> select([p, u], %{poke: p, poker: u})
    |> order_by([p, _], desc: p.inserted_at)
    |> Repo.all()
  end

  # === Blocking ===

  def block_user(blocker_id, blocked_id) do
    Repo.transaction(fn ->
      # Create block
      %Block{}
      |> Block.changeset(%{blocker_id: blocker_id, blocked_id: blocked_id})
      |> Repo.insert!(on_conflict: :nothing)

      # Remove friendship if exists
      unfriend(blocker_id, blocked_id)

      # Cancel pending friend requests in both directions
      from(fr in FriendRequest,
        where:
          ((fr.sender_id == ^blocker_id and fr.receiver_id == ^blocked_id) or
             (fr.sender_id == ^blocked_id and fr.receiver_id == ^blocker_id)) and
            fr.status == "pending"
      )
      |> Repo.update_all(set: [status: "cancelled"])

      # Remove pokes in both directions
      from(p in Poke,
        where:
          (p.poker_id == ^blocker_id and p.pokee_id == ^blocked_id) or
            (p.poker_id == ^blocked_id and p.pokee_id == ^blocker_id)
      )
      |> Repo.delete_all()
    end)
  end

  def unblock_user(blocker_id, blocked_id) do
    from(b in Block, where: b.blocker_id == ^blocker_id and b.blocked_id == ^blocked_id)
    |> Repo.delete_all()

    :ok
  end

  def blocked?(user_id, other_id) do
    Repo.exists?(
      from b in Block,
        where:
          (b.blocker_id == ^user_id and b.blocked_id == ^other_id) or
            (b.blocker_id == ^other_id and b.blocked_id == ^user_id)
    )
  end

  def list_blocked_users(user_id) do
    Block
    |> where([b], b.blocker_id == ^user_id)
    |> join(:inner, [b], u in User, on: u.id == b.blocked_id)
    |> select([b, u], u)
    |> Repo.all()
  end

  defp blocked_user_ids(user_id) do
    blocker_ids =
      from(b in Block, where: b.blocked_id == ^user_id, select: b.blocker_id) |> Repo.all()

    blocked_ids =
      from(b in Block, where: b.blocker_id == ^user_id, select: b.blocked_id) |> Repo.all()

    Enum.uniq(blocker_ids ++ blocked_ids)
  end

  # === Relationship Status Helpers ===

  def relationship_status(user_id, other_id) do
    cond do
      user_id == other_id -> :self
      blocked?(user_id, other_id) -> :blocked
      friends?(user_id, other_id) -> :friends
      pending_request?(user_id, other_id) -> :request_sent
      pending_request?(other_id, user_id) -> :request_received
      true -> :none
    end
  end
end
