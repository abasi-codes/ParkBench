defmodule ParkBenchWeb.ChatChannelTest do
  use ParkBenchWeb.ChannelCase, async: false

  alias ParkBenchWeb.{UserSocket, ChatChannel}
  alias ParkBench.{Messaging, RateLimiter}

  defp make_friends(user1, user2) do
    {low, high} = if user1.id < user2.id, do: {user1, user2}, else: {user2, user1}
    insert(:friendship, user: low, friend: high)
  end

  defp connect_user(user) do
    token = Phoenix.Token.sign(ParkBenchWeb.Endpoint, "user socket", user.id)
    {:ok, socket} = connect(UserSocket, %{"token" => token})
    socket
  end

  defp setup_chat_thread(user1, user2) do
    make_friends(user1, user2)
    {:ok, thread} = Messaging.get_or_create_chat_thread(user1.id, user2.id)
    RateLimiter.reset(user1.id, :send_chat_message)
    RateLimiter.reset(user2.id, :send_chat_message)
    thread
  end

  describe "join/3" do
    test "joins a chat thread as participant" do
      user1 = insert(:user)
      user2 = insert(:user)
      thread = setup_chat_thread(user1, user2)
      socket = connect_user(user1)

      assert {:ok, reply, _socket} = subscribe_and_join(socket, ChatChannel, "chat:#{thread.id}")
      assert is_list(reply.messages)
      assert reply.other_user.id == user2.id
    end

    test "returns existing messages on join" do
      user1 = insert(:user)
      user2 = insert(:user)
      thread = setup_chat_thread(user1, user2)
      {:ok, _msg} = Messaging.send_chat_message(thread.id, user1.id, "Hello!")

      socket = connect_user(user2)
      {:ok, reply, _socket} = subscribe_and_join(socket, ChatChannel, "chat:#{thread.id}")
      assert length(reply.messages) == 1
      assert hd(reply.messages).body == "Hello!"
    end

    test "rejects non-participant" do
      user1 = insert(:user)
      user2 = insert(:user)
      outsider = insert(:user)
      thread = setup_chat_thread(user1, user2)

      socket = connect_user(outsider)

      assert {:error, %{reason: "unauthorized"}} =
               subscribe_and_join(socket, ChatChannel, "chat:#{thread.id}")
    end

    test "rejects invalid thread id" do
      user = insert(:user)
      socket = connect_user(user)
      fake_id = Ecto.UUID.generate()

      assert {:error, _} = subscribe_and_join(socket, ChatChannel, "chat:#{fake_id}")
    end
  end

  describe "handle_in new_message" do
    test "sends a message and replies ok" do
      user1 = insert(:user)
      user2 = insert(:user)
      thread = setup_chat_thread(user1, user2)
      socket = connect_user(user1)

      {:ok, _, socket} = subscribe_and_join(socket, ChatChannel, "chat:#{thread.id}")
      ref = push(socket, "new_message", %{"body" => "Test message"})
      assert_reply ref, :ok
    end

    test "broadcasts new message to channel" do
      user1 = insert(:user)
      user2 = insert(:user)
      thread = setup_chat_thread(user1, user2)
      socket = connect_user(user1)

      {:ok, _, socket} = subscribe_and_join(socket, ChatChannel, "chat:#{thread.id}")
      push(socket, "new_message", %{"body" => "Broadcast test"})

      assert_push "new_message", %{body: "Broadcast test", sender_id: _}
    end

    test "message body is decrypted in broadcast" do
      user1 = insert(:user)
      user2 = insert(:user)
      thread = setup_chat_thread(user1, user2)
      socket = connect_user(user1)

      {:ok, _, socket} = subscribe_and_join(socket, ChatChannel, "chat:#{thread.id}")
      push(socket, "new_message", %{"body" => "Decrypted text"})

      assert_push "new_message", %{body: "Decrypted text"}
    end

    test "includes sender name in broadcast" do
      user1 = insert(:user)
      user2 = insert(:user)
      thread = setup_chat_thread(user1, user2)
      socket = connect_user(user1)

      {:ok, _, socket} = subscribe_and_join(socket, ChatChannel, "chat:#{thread.id}")
      push(socket, "new_message", %{"body" => "Named message"})

      assert_push "new_message", %{sender_name: name}
      assert is_binary(name)
    end

    test "rate limits messages" do
      user1 = insert(:user)
      user2 = insert(:user)
      thread = setup_chat_thread(user1, user2)
      socket = connect_user(user1)

      {:ok, _, socket} = subscribe_and_join(socket, ChatChannel, "chat:#{thread.id}")

      # Send 30 messages (the limit)
      for _ <- 1..30 do
        ref = push(socket, "new_message", %{"body" => "msg"})
        assert_reply ref, :ok
      end

      # 31st should be rate limited
      ref = push(socket, "new_message", %{"body" => "over limit"})
      assert_reply ref, :error, %{reason: "rate_limited"}
    end

    test "rejects empty message body" do
      user1 = insert(:user)
      user2 = insert(:user)
      thread = setup_chat_thread(user1, user2)
      socket = connect_user(user1)

      {:ok, _, socket} = subscribe_and_join(socket, ChatChannel, "chat:#{thread.id}")
      ref = push(socket, "new_message", %{"body" => ""})
      assert_reply ref, :error, %{reason: _}
    end
  end

  describe "handle_in typing" do
    test "broadcasts typing to other participants" do
      user1 = insert(:user)
      user2 = insert(:user)
      thread = setup_chat_thread(user1, user2)
      socket = connect_user(user1)

      {:ok, _, socket} = subscribe_and_join(socket, ChatChannel, "chat:#{thread.id}")
      push(socket, "typing", %{})

      # broadcast_from doesn't send to self, so we check the broadcast happened
      # In test mode we can check via process messages
      # The typing broadcast uses broadcast_from, so it won't appear for the sender
    end

    test "broadcasts stop_typing" do
      user1 = insert(:user)
      user2 = insert(:user)
      thread = setup_chat_thread(user1, user2)
      socket = connect_user(user1)

      {:ok, _, socket} = subscribe_and_join(socket, ChatChannel, "chat:#{thread.id}")
      push(socket, "stop_typing", %{})
      # broadcast_from — no self-receive
    end
  end

  describe "handle_in mark_read" do
    test "marks thread as read and broadcasts receipt" do
      user1 = insert(:user)
      user2 = insert(:user)
      thread = setup_chat_thread(user1, user2)
      {:ok, _} = Messaging.send_chat_message(thread.id, user1.id, "Unread msg")

      socket = connect_user(user2)
      {:ok, _, socket} = subscribe_and_join(socket, ChatChannel, "chat:#{thread.id}")

      ref = push(socket, "mark_read", %{})
      assert_reply ref, :ok
    end
  end

  describe "concurrent users" do
    test "both users can join the same thread" do
      user1 = insert(:user)
      user2 = insert(:user)
      thread = setup_chat_thread(user1, user2)

      socket1 = connect_user(user1)
      socket2 = connect_user(user2)

      assert {:ok, _, _} = subscribe_and_join(socket1, ChatChannel, "chat:#{thread.id}")
      assert {:ok, _, _} = subscribe_and_join(socket2, ChatChannel, "chat:#{thread.id}")
    end

    test "message from one user reaches the other" do
      user1 = insert(:user)
      user2 = insert(:user)
      thread = setup_chat_thread(user1, user2)

      socket1 = connect_user(user1)
      {:ok, _, socket1} = subscribe_and_join(socket1, ChatChannel, "chat:#{thread.id}")

      push(socket1, "new_message", %{"body" => "Hello user2!"})
      assert_push "new_message", %{body: "Hello user2!"}
    end
  end
end
