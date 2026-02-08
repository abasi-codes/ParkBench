defmodule SunporchWeb.PresenceChannelTest do
  use SunporchWeb.ChannelCase, async: false

  alias SunporchWeb.{UserSocket, PresenceChannel}
  alias Sunporch.RateLimiter

  defp make_friends(user1, user2) do
    {low, high} = if user1.id < user2.id, do: {user1, user2}, else: {user2, user1}
    insert(:friendship, user: low, friend: high)
  end

  defp connect_user(user) do
    token = Phoenix.Token.sign(SunporchWeb.Endpoint, "user socket", user.id)
    {:ok, socket} = connect(UserSocket, %{"token" => token})
    socket
  end

  describe "join presence:lobby" do
    test "joins successfully" do
      user = insert(:user)
      socket = connect_user(user)

      assert {:ok, _, _socket} = subscribe_and_join(socket, PresenceChannel, "presence:lobby")
    end

    test "receives presence_state after join" do
      user = insert(:user)
      socket = connect_user(user)

      {:ok, _, _socket} = subscribe_and_join(socket, PresenceChannel, "presence:lobby")
      assert_push "presence_state", _state
    end

    test "tracks user in presence" do
      user = insert(:user)
      socket = connect_user(user)

      {:ok, _, _socket} = subscribe_and_join(socket, PresenceChannel, "presence:lobby")
      assert_push "presence_state", state

      assert Map.has_key?(state, user.id)
    end
  end

  describe "get_friends" do
    test "returns friend list" do
      user1 = insert(:user)
      user2 = insert(:user)
      make_friends(user1, user2)

      socket = connect_user(user1)
      {:ok, _, socket} = subscribe_and_join(socket, PresenceChannel, "presence:lobby")

      ref = push(socket, "get_friends", %{})
      assert_reply ref, :ok, %{friends: friends}
      assert length(friends) == 1
      assert hd(friends).id == user2.id
    end

    test "returns empty list for user with no friends" do
      user = insert(:user)
      socket = connect_user(user)
      {:ok, _, socket} = subscribe_and_join(socket, PresenceChannel, "presence:lobby")

      ref = push(socket, "get_friends", %{})
      assert_reply ref, :ok, %{friends: []}
    end

    test "friend data includes display_name and slug" do
      user1 = insert(:user)
      user2 = insert(:user)
      make_friends(user1, user2)

      socket = connect_user(user1)
      {:ok, _, socket} = subscribe_and_join(socket, PresenceChannel, "presence:lobby")

      ref = push(socket, "get_friends", %{})
      assert_reply ref, :ok, %{friends: [friend]}
      assert friend.display_name == user2.display_name
      assert friend.slug == user2.slug
    end
  end

  describe "open_chat" do
    test "creates a chat thread between friends" do
      user1 = insert(:user)
      user2 = insert(:user)
      make_friends(user1, user2)

      socket = connect_user(user1)
      {:ok, _, socket} = subscribe_and_join(socket, PresenceChannel, "presence:lobby")

      ref = push(socket, "open_chat", %{"friend_id" => user2.id})
      assert_reply ref, :ok, %{thread_id: thread_id}
      assert is_binary(thread_id)
    end

    test "returns same thread on repeated open_chat" do
      user1 = insert(:user)
      user2 = insert(:user)
      make_friends(user1, user2)

      socket = connect_user(user1)
      {:ok, _, socket} = subscribe_and_join(socket, PresenceChannel, "presence:lobby")

      ref1 = push(socket, "open_chat", %{"friend_id" => user2.id})
      assert_reply ref1, :ok, %{thread_id: tid1}

      ref2 = push(socket, "open_chat", %{"friend_id" => user2.id})
      assert_reply ref2, :ok, %{thread_id: tid2}

      assert tid1 == tid2
    end

    test "fails for non-friend" do
      user1 = insert(:user)
      user2 = insert(:user)

      socket = connect_user(user1)
      {:ok, _, socket} = subscribe_and_join(socket, PresenceChannel, "presence:lobby")

      ref = push(socket, "open_chat", %{"friend_id" => user2.id})
      assert_reply ref, :error, %{reason: "not_friends"}
    end

    test "fails for blocked user" do
      user1 = insert(:user)
      user2 = insert(:user)
      make_friends(user1, user2)
      insert(:block, blocker: user1, blocked: user2)

      socket = connect_user(user1)
      {:ok, _, socket} = subscribe_and_join(socket, PresenceChannel, "presence:lobby")

      ref = push(socket, "open_chat", %{"friend_id" => user2.id})
      assert_reply ref, :error, %{reason: "blocked"}
    end
  end
end
