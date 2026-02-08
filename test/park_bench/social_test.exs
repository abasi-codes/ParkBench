defmodule ParkBench.SocialTest do
  use ParkBench.DataCase, async: true

  alias ParkBench.Social

  # Helper to create two users and make them friends
  defp make_friends do
    user1 = insert(:user)
    user2 = insert(:user)
    make_friends(user1, user2)
    {user1, user2}
  end

  defp make_friends(user1, user2) do
    {low, high} =
      if user1.id < user2.id, do: {user1, user2}, else: {user2, user1}

    insert(:friendship, user: low, friend: high)
  end

  # ──────────────────────────────────────────────
  # Friendships
  # ──────────────────────────────────────────────

  describe "friends?/2" do
    test "returns true when users are friends" do
      {user1, user2} = make_friends()
      assert Social.friends?(user1.id, user2.id)
      # Order should not matter
      assert Social.friends?(user2.id, user1.id)
    end

    test "returns false when users are not friends" do
      user1 = insert(:user)
      user2 = insert(:user)
      refute Social.friends?(user1.id, user2.id)
    end
  end

  describe "list_friends/1" do
    test "lists all friends of a user" do
      user1 = insert(:user)
      user2 = insert(:user)
      user3 = insert(:user)

      make_friends(user1, user2)
      make_friends(user1, user3)

      friends = Social.list_friends(user1.id)
      friend_ids = Enum.map(friends, & &1.id) |> Enum.sort()
      assert friend_ids == Enum.sort([user2.id, user3.id])
    end
  end

  describe "list_friends_paginated/3" do
    test "paginates friends" do
      user = insert(:user)
      friends = for _ <- 1..5, do: insert(:user)
      Enum.each(friends, fn f -> make_friends(user, f) end)

      page1 = Social.list_friends_paginated(user.id, 1, 3)
      assert length(page1) == 3

      page2 = Social.list_friends_paginated(user.id, 2, 3)
      assert length(page2) == 2
    end
  end

  describe "count_friends/1" do
    test "returns the number of friends" do
      user = insert(:user)
      f1 = insert(:user)
      f2 = insert(:user)

      make_friends(user, f1)
      make_friends(user, f2)

      assert Social.count_friends(user.id) == 2
    end

    test "returns 0 for a user with no friends" do
      user = insert(:user)
      assert Social.count_friends(user.id) == 0
    end
  end

  describe "mutual_friends/2" do
    test "returns mutual friends between two users" do
      user1 = insert(:user)
      user2 = insert(:user)
      mutual = insert(:user)
      only_user1_friend = insert(:user)

      make_friends(user1, mutual)
      make_friends(user2, mutual)
      make_friends(user1, only_user1_friend)

      mutuals = Social.mutual_friends(user1.id, user2.id)
      assert length(mutuals) == 1
      assert hd(mutuals).id == mutual.id
    end
  end

  describe "count_mutual_friends/2" do
    test "counts mutual friends" do
      user1 = insert(:user)
      user2 = insert(:user)
      mutual = insert(:user)

      make_friends(user1, mutual)
      make_friends(user2, mutual)

      assert Social.count_mutual_friends(user1.id, user2.id) == 1
    end
  end

  # ──────────────────────────────────────────────
  # Friend Requests
  # ──────────────────────────────────────────────

  describe "send_friend_request/2" do
    test "creates a pending friend request" do
      sender = insert(:user)
      receiver = insert(:user)

      assert {:ok, request} = Social.send_friend_request(sender.id, receiver.id)
      assert request.sender_id == sender.id
      assert request.receiver_id == receiver.id
      assert request.status == "pending"
    end

    test "returns error for self-request" do
      user = insert(:user)
      assert {:error, :cannot_friend_self} = Social.send_friend_request(user.id, user.id)
    end

    test "returns error when already friends" do
      {user1, user2} = make_friends()
      assert {:error, :already_friends} = Social.send_friend_request(user1.id, user2.id)
    end

    test "returns error when blocked" do
      blocker = insert(:user)
      blocked = insert(:user)
      insert(:block, blocker: blocker, blocked: blocked)

      assert {:error, :blocked} = Social.send_friend_request(blocker.id, blocked.id)
    end

    test "returns error when blocked by the other user" do
      user1 = insert(:user)
      user2 = insert(:user)
      insert(:block, blocker: user2, blocked: user1)

      assert {:error, :blocked} = Social.send_friend_request(user1.id, user2.id)
    end

    test "returns error when request already pending" do
      sender = insert(:user)
      receiver = insert(:user)

      {:ok, _} = Social.send_friend_request(sender.id, receiver.id)
      assert {:error, :already_requested} = Social.send_friend_request(sender.id, receiver.id)
    end

    test "auto-accepts when reverse request exists" do
      user1 = insert(:user)
      user2 = insert(:user)

      {:ok, _} = Social.send_friend_request(user1.id, user2.id)
      assert {:ok, _} = Social.send_friend_request(user2.id, user1.id)

      assert Social.friends?(user1.id, user2.id)
    end
  end

  describe "accept_friend_request/2" do
    test "accepts request and creates friendship" do
      sender = insert(:user)
      receiver = insert(:user)
      {:ok, request} = Social.send_friend_request(sender.id, receiver.id)

      assert {:ok, _} = Social.accept_friend_request(request.id, receiver.id)
      assert Social.friends?(sender.id, receiver.id)
    end

    test "returns error when non-receiver tries to accept" do
      sender = insert(:user)
      receiver = insert(:user)
      other = insert(:user)
      {:ok, request} = Social.send_friend_request(sender.id, receiver.id)

      assert {:error, :unauthorized} = Social.accept_friend_request(request.id, other.id)
    end
  end

  describe "reject_friend_request/2" do
    test "rejects the request" do
      sender = insert(:user)
      receiver = insert(:user)
      {:ok, request} = Social.send_friend_request(sender.id, receiver.id)

      assert {:ok, rejected} = Social.reject_friend_request(request.id, receiver.id)
      assert rejected.status == "rejected"
      refute Social.friends?(sender.id, receiver.id)
    end

    test "returns error when non-receiver tries to reject" do
      sender = insert(:user)
      receiver = insert(:user)
      other = insert(:user)
      {:ok, request} = Social.send_friend_request(sender.id, receiver.id)

      assert {:error, :unauthorized} = Social.reject_friend_request(request.id, other.id)
    end
  end

  describe "cancel_friend_request/2" do
    test "cancels the request" do
      sender = insert(:user)
      receiver = insert(:user)
      {:ok, request} = Social.send_friend_request(sender.id, receiver.id)

      assert {:ok, cancelled} = Social.cancel_friend_request(request.id, sender.id)
      assert cancelled.status == "cancelled"
    end

    test "returns error when non-sender tries to cancel" do
      sender = insert(:user)
      receiver = insert(:user)
      {:ok, request} = Social.send_friend_request(sender.id, receiver.id)

      assert {:error, :unauthorized} = Social.cancel_friend_request(request.id, receiver.id)
    end
  end

  describe "list_pending_requests_for/1" do
    test "returns pending requests for a user" do
      sender = insert(:user)
      receiver = insert(:user)
      {:ok, _} = Social.send_friend_request(sender.id, receiver.id)

      pending = Social.list_pending_requests_for(receiver.id)
      assert length(pending) == 1
      assert hd(pending).sender.id == sender.id
    end
  end

  describe "list_sent_requests/1" do
    test "returns sent pending requests" do
      sender = insert(:user)
      receiver = insert(:user)
      {:ok, _} = Social.send_friend_request(sender.id, receiver.id)

      sent = Social.list_sent_requests(sender.id)
      assert length(sent) == 1
      assert hd(sent).receiver.id == receiver.id
    end
  end

  describe "count_pending_requests/1" do
    test "counts pending requests for receiver" do
      sender1 = insert(:user)
      sender2 = insert(:user)
      receiver = insert(:user)
      {:ok, _} = Social.send_friend_request(sender1.id, receiver.id)
      {:ok, _} = Social.send_friend_request(sender2.id, receiver.id)

      assert Social.count_pending_requests(receiver.id) == 2
    end
  end

  # ──────────────────────────────────────────────
  # Unfriend
  # ──────────────────────────────────────────────

  describe "unfriend/2" do
    test "removes a friendship" do
      {user1, user2} = make_friends()
      assert :ok = Social.unfriend(user1.id, user2.id)
      refute Social.friends?(user1.id, user2.id)
    end
  end

  # ──────────────────────────────────────────────
  # People You May Know
  # ──────────────────────────────────────────────

  describe "people_you_may_know/2" do
    test "returns friends of friends" do
      user = insert(:user)
      friend = insert(:user)
      fof = insert(:user)

      make_friends(user, friend)
      make_friends(friend, fof)

      suggestions = Social.people_you_may_know(user.id)
      suggestion_ids = Enum.map(suggestions, & &1.user.id)
      assert fof.id in suggestion_ids
    end

    test "returns empty list when user has no friends" do
      user = insert(:user)
      assert Social.people_you_may_know(user.id) == []
    end

    test "does not suggest existing friends" do
      user = insert(:user)
      friend = insert(:user)
      make_friends(user, friend)

      suggestions = Social.people_you_may_know(user.id)
      suggestion_ids = Enum.map(suggestions, & &1.user.id)
      refute friend.id in suggestion_ids
    end
  end

  # ──────────────────────────────────────────────
  # Pokes
  # ──────────────────────────────────────────────

  describe "poke/2" do
    test "creates a poke between friends" do
      {user1, user2} = make_friends()
      assert {:ok, poke} = Social.poke(user1.id, user2.id)
      assert poke.poker_id == user1.id
      assert poke.pokee_id == user2.id
    end

    test "returns error for self-poke" do
      user = insert(:user)
      assert {:error, :cannot_poke_self} = Social.poke(user.id, user.id)
    end

    test "returns error when not friends" do
      user1 = insert(:user)
      user2 = insert(:user)
      assert {:error, :not_friends} = Social.poke(user1.id, user2.id)
    end

    test "returns error when blocked" do
      user1 = insert(:user)
      user2 = insert(:user)
      make_friends(user1, user2)
      insert(:block, blocker: user1, blocked: user2)

      assert {:error, :blocked} = Social.poke(user1.id, user2.id)
    end
  end

  describe "poke_back/2" do
    test "removes incoming poke and creates reverse" do
      {user1, user2} = make_friends()
      {:ok, _} = Social.poke(user1.id, user2.id)

      assert {:ok, _} = Social.poke_back(user2.id, user1.id)

      # Original poke should be gone, reverse poke should exist
      pokes = Social.list_pending_pokes(user1.id)
      assert length(pokes) == 1
      assert hd(pokes).poker.id == user2.id
    end
  end

  describe "dismiss_poke/2" do
    test "removes the poke" do
      {user1, user2} = make_friends()
      {:ok, _} = Social.poke(user1.id, user2.id)

      assert :ok = Social.dismiss_poke(user1.id, user2.id)
      assert Social.list_pending_pokes(user2.id) == []
    end
  end

  describe "list_pending_pokes/1" do
    test "returns pokes for the user" do
      {user1, user2} = make_friends()
      {:ok, _} = Social.poke(user1.id, user2.id)

      pokes = Social.list_pending_pokes(user2.id)
      assert length(pokes) == 1
      assert hd(pokes).poker.id == user1.id
    end
  end

  # ──────────────────────────────────────────────
  # Blocking
  # ──────────────────────────────────────────────

  describe "block_user/2" do
    test "creates a block record" do
      user1 = insert(:user)
      user2 = insert(:user)

      assert {:ok, _} = Social.block_user(user1.id, user2.id)
      assert Social.blocked?(user1.id, user2.id)
    end

    test "removes friendship when blocking" do
      {user1, user2} = make_friends()
      assert Social.friends?(user1.id, user2.id)

      {:ok, _} = Social.block_user(user1.id, user2.id)
      refute Social.friends?(user1.id, user2.id)
    end

    test "cancels pending friend requests in both directions" do
      sender = insert(:user)
      receiver = insert(:user)
      {:ok, _request} = Social.send_friend_request(sender.id, receiver.id)

      {:ok, _} = Social.block_user(receiver.id, sender.id)
      assert Social.count_pending_requests(receiver.id) == 0
    end

    test "removes pokes in both directions" do
      {user1, user2} = make_friends()
      {:ok, _} = Social.poke(user1.id, user2.id)

      {:ok, _} = Social.block_user(user1.id, user2.id)
      assert Social.list_pending_pokes(user2.id) == []
    end
  end

  describe "unblock_user/2" do
    test "removes the block" do
      user1 = insert(:user)
      user2 = insert(:user)
      {:ok, _} = Social.block_user(user1.id, user2.id)

      assert :ok = Social.unblock_user(user1.id, user2.id)
      refute Social.blocked?(user1.id, user2.id)
    end
  end

  describe "blocked?/2" do
    test "returns true when either direction is blocked" do
      user1 = insert(:user)
      user2 = insert(:user)
      insert(:block, blocker: user1, blocked: user2)

      assert Social.blocked?(user1.id, user2.id)
      # Also detects in reverse
      assert Social.blocked?(user2.id, user1.id)
    end

    test "returns false when no block exists" do
      user1 = insert(:user)
      user2 = insert(:user)
      refute Social.blocked?(user1.id, user2.id)
    end
  end

  describe "list_blocked_users/1" do
    test "returns users blocked by the given user" do
      blocker = insert(:user)
      blocked1 = insert(:user)
      blocked2 = insert(:user)
      insert(:block, blocker: blocker, blocked: blocked1)
      insert(:block, blocker: blocker, blocked: blocked2)

      blocked = Social.list_blocked_users(blocker.id)
      blocked_ids = Enum.map(blocked, & &1.id) |> Enum.sort()
      assert blocked_ids == Enum.sort([blocked1.id, blocked2.id])
    end
  end

  # ──────────────────────────────────────────────
  # Relationship Status
  # ──────────────────────────────────────────────

  describe "relationship_status/2" do
    test "returns :self for same user" do
      user = insert(:user)
      assert Social.relationship_status(user.id, user.id) == :self
    end

    test "returns :blocked when blocked" do
      user1 = insert(:user)
      user2 = insert(:user)
      insert(:block, blocker: user1, blocked: user2)
      assert Social.relationship_status(user1.id, user2.id) == :blocked
    end

    test "returns :friends when friends" do
      {user1, user2} = make_friends()
      assert Social.relationship_status(user1.id, user2.id) == :friends
    end

    test "returns :request_sent when pending request exists" do
      sender = insert(:user)
      receiver = insert(:user)
      {:ok, _} = Social.send_friend_request(sender.id, receiver.id)
      assert Social.relationship_status(sender.id, receiver.id) == :request_sent
    end

    test "returns :request_received when the other user sent a request" do
      sender = insert(:user)
      receiver = insert(:user)
      {:ok, _} = Social.send_friend_request(sender.id, receiver.id)
      assert Social.relationship_status(receiver.id, sender.id) == :request_received
    end

    test "returns :none for strangers" do
      user1 = insert(:user)
      user2 = insert(:user)
      assert Social.relationship_status(user1.id, user2.id) == :none
    end
  end
end
