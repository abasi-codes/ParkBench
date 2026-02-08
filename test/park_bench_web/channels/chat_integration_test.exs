defmodule ParkBenchWeb.ChatIntegrationTest do
  use ParkBenchWeb.ChannelCase, async: false

  alias ParkBenchWeb.{UserSocket, ChatChannel, PresenceChannel}
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

  describe "end-to-end chat flow" do
    test "open chat from presence, join thread, send message, receive it" do
      user1 = insert(:user)
      user2 = insert(:user)
      make_friends(user1, user2)
      RateLimiter.reset(user1.id, :send_chat_message)

      # User1 joins presence and opens a chat
      socket1 = connect_user(user1)
      {:ok, _, presence_socket} = subscribe_and_join(socket1, PresenceChannel, "presence:lobby")

      ref = push(presence_socket, "open_chat", %{"friend_id" => user2.id})
      assert_reply ref, :ok, %{thread_id: thread_id}

      # User1 joins the chat channel
      {:ok, _, chat_socket1} = subscribe_and_join(socket1, ChatChannel, "chat:#{thread_id}")

      # User1 sends a message
      ref = push(chat_socket1, "new_message", %{"body" => "Hey there!"})
      assert_reply ref, :ok

      # User1 should receive the message broadcast
      assert_push "new_message", %{body: "Hey there!", sender_id: sender_id}
      assert sender_id == user1.id
    end

    test "message shows in inbox for both users" do
      user1 = insert(:user)
      user2 = insert(:user)
      make_friends(user1, user2)
      RateLimiter.reset(user1.id, :send_chat_message)

      {:ok, thread} = Messaging.get_or_create_chat_thread(user1.id, user2.id)
      {:ok, _msg} = Messaging.send_chat_message(thread.id, user1.id, "Inbox test")

      inbox1 = Messaging.list_inbox(user1.id)
      inbox2 = Messaging.list_inbox(user2.id)

      assert length(inbox1) == 1
      assert length(inbox2) == 1
      assert hd(inbox1).thread.id == thread.id
      assert hd(inbox2).thread.id == thread.id
    end

    test "chat thread is separate from inbox thread between same users" do
      user1 = insert(:user)
      user2 = insert(:user)
      make_friends(user1, user2)
      RateLimiter.reset(user1.id, :send_chat_message)
      RateLimiter.reset(user1.id, :create_thread)

      # Create inbox thread
      {:ok, %{thread: inbox_thread}} =
        Messaging.create_thread(user1.id, user2.id, "Subject", "Hello")

      # Create chat thread
      {:ok, chat_thread} = Messaging.get_or_create_chat_thread(user1.id, user2.id)

      assert inbox_thread.id != chat_thread.id
      assert inbox_thread.type == "inbox"
      assert chat_thread.type == "chat"
    end

    test "unread count includes chat messages" do
      user1 = insert(:user)
      user2 = insert(:user)
      make_friends(user1, user2)
      RateLimiter.reset(user1.id, :send_chat_message)

      {:ok, thread} = Messaging.get_or_create_chat_thread(user1.id, user2.id)
      {:ok, _msg} = Messaging.send_chat_message(thread.id, user1.id, "Unread chat")

      # user2 has an unread message
      assert Messaging.count_unread(user2.id) >= 1
    end

    test "marking read clears unread for chat" do
      user1 = insert(:user)
      user2 = insert(:user)
      make_friends(user1, user2)
      RateLimiter.reset(user1.id, :send_chat_message)

      {:ok, thread} = Messaging.get_or_create_chat_thread(user1.id, user2.id)
      {:ok, _msg} = Messaging.send_chat_message(thread.id, user1.id, "Will be read")

      # User2 marks as read
      {:ok, _} = Messaging.mark_chat_read(thread.id, user2.id)

      # Count for user2 should be 0 (for this thread at least)
      unread_count = Messaging.count_unread(user2.id)
      assert unread_count == 0
    end

    test "multiple chat threads with different friends" do
      user1 = insert(:user)
      user2 = insert(:user)
      user3 = insert(:user)
      make_friends(user1, user2)
      make_friends(user1, user3)

      {:ok, thread_a} = Messaging.get_or_create_chat_thread(user1.id, user2.id)
      {:ok, thread_b} = Messaging.get_or_create_chat_thread(user1.id, user3.id)

      assert thread_a.id != thread_b.id
    end

    test "get_thread works for chat threads" do
      user1 = insert(:user)
      user2 = insert(:user)
      make_friends(user1, user2)
      RateLimiter.reset(user1.id, :send_chat_message)

      {:ok, thread} = Messaging.get_or_create_chat_thread(user1.id, user2.id)
      {:ok, _msg} = Messaging.send_chat_message(thread.id, user1.id, "Chat msg")

      {:ok, result} = Messaging.get_thread(thread.id, user1.id)
      assert result.thread.type == "chat"
      assert length(result.messages) == 1
      assert hd(result.messages).body == "Chat msg"
    end

    test "delete_thread_for_user works for chat threads" do
      user1 = insert(:user)
      user2 = insert(:user)
      make_friends(user1, user2)

      {:ok, thread} = Messaging.get_or_create_chat_thread(user1.id, user2.id)
      assert {:ok, _} = Messaging.delete_thread_for_user(thread.id, user1.id)

      # Thread should not appear in user1's inbox
      inbox = Messaging.list_inbox(user1.id)
      assert Enum.empty?(inbox)
    end
  end
end
