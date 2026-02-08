defmodule ParkBench.Messaging.ChatTest do
  use ParkBench.DataCase, async: true

  use Oban.Testing, repo: ParkBench.Repo

  alias ParkBench.Messaging
  alias ParkBench.RateLimiter

  defp make_friends(user1, user2) do
    {low, high} = if user1.id < user2.id, do: {user1, user2}, else: {user2, user1}
    insert(:friendship, user: low, friend: high)
    {low, high}
  end

  describe "get_or_create_chat_thread/2" do
    test "creates a new chat thread between friends" do
      user1 = insert(:user)
      user2 = insert(:user)
      make_friends(user1, user2)

      assert {:ok, thread} = Messaging.get_or_create_chat_thread(user1.id, user2.id)
      assert thread.type == "chat"
      assert is_nil(thread.subject)
    end

    test "returns existing chat thread if one exists" do
      user1 = insert(:user)
      user2 = insert(:user)
      make_friends(user1, user2)

      {:ok, thread1} = Messaging.get_or_create_chat_thread(user1.id, user2.id)
      {:ok, thread2} = Messaging.get_or_create_chat_thread(user1.id, user2.id)

      assert thread1.id == thread2.id
    end

    test "returns same thread regardless of argument order" do
      user1 = insert(:user)
      user2 = insert(:user)
      make_friends(user1, user2)

      {:ok, thread1} = Messaging.get_or_create_chat_thread(user1.id, user2.id)
      {:ok, thread2} = Messaging.get_or_create_chat_thread(user2.id, user1.id)

      assert thread1.id == thread2.id
    end

    test "fails when users are not friends" do
      user1 = insert(:user)
      user2 = insert(:user)

      assert {:error, :not_friends} = Messaging.get_or_create_chat_thread(user1.id, user2.id)
    end

    test "fails when users are blocked" do
      user1 = insert(:user)
      user2 = insert(:user)
      make_friends(user1, user2)
      insert(:block, blocker: user1, blocked: user2)

      assert {:error, :blocked} = Messaging.get_or_create_chat_thread(user1.id, user2.id)
    end

    test "fails when messaging self" do
      user = insert(:user)

      assert {:error, :cannot_message_self} =
               Messaging.get_or_create_chat_thread(user.id, user.id)
    end
  end

  describe "send_chat_message/3" do
    setup do
      user1 = insert(:user)
      user2 = insert(:user)
      make_friends(user1, user2)
      {:ok, thread} = Messaging.get_or_create_chat_thread(user1.id, user2.id)
      RateLimiter.reset(user1.id, :send_chat_message)
      RateLimiter.reset(user2.id, :send_chat_message)
      %{user1: user1, user2: user2, thread: thread}
    end

    test "sends a chat message", %{user1: user1, thread: thread} do
      assert {:ok, message} = Messaging.send_chat_message(thread.id, user1.id, "Hello!")
      assert message.sender_id == user1.id
    end

    test "message is encrypted in database", %{user1: user1, thread: thread} do
      {:ok, message} = Messaging.send_chat_message(thread.id, user1.id, "Secret chat")
      db_msg = Repo.get!(ParkBench.Messaging.Message, message.id)
      assert db_msg.encrypted_body != "Secret chat"
      assert is_binary(db_msg.encrypted_body)
    end

    test "message appears in thread messages", %{user1: user1, thread: thread} do
      {:ok, _msg} = Messaging.send_chat_message(thread.id, user1.id, "Chat message")
      messages = Messaging.list_messages(thread.id)
      assert length(messages) == 1
      assert hd(messages).body == "Chat message"
    end

    test "updates thread last_message_at", %{user1: user1, thread: thread} do
      old_time = thread.last_message_at
      # Ensure at least 1 second passes
      Process.sleep(1100)
      {:ok, _msg} = Messaging.send_chat_message(thread.id, user1.id, "New message")
      updated = Repo.get!(ParkBench.Messaging.MessageThread, thread.id)
      assert DateTime.compare(updated.last_message_at, old_time) == :gt
    end

    test "returns error for non-participant", %{thread: thread} do
      outsider = insert(:user)

      assert {:error, :not_participant} =
               Messaging.send_chat_message(thread.id, outsider.id, "Hi")
    end

    test "rate limits chat messages", %{user1: user1, thread: thread} do
      # Send 30 messages (the limit)
      for _ <- 1..30 do
        assert {:ok, _} = Messaging.send_chat_message(thread.id, user1.id, "msg")
      end

      # 31st should be rate limited
      assert {:error, :rate_limited} = Messaging.send_chat_message(thread.id, user1.id, "msg")
    end

    test "broadcasts to thread PubSub", %{user1: user1, thread: thread} do
      Phoenix.PubSub.subscribe(ParkBench.PubSub, "thread:#{thread.id}")
      {:ok, _msg} = Messaging.send_chat_message(thread.id, user1.id, "Broadcast test")
      assert_receive {:new_message, %{sender_id: _}}
    end

    test "broadcasts to other user's PubSub", %{user1: user1, user2: user2, thread: thread} do
      Phoenix.PubSub.subscribe(ParkBench.PubSub, "user:#{user2.id}")
      {:ok, _msg} = Messaging.send_chat_message(thread.id, user1.id, "Notify test")
      assert_receive {:new_message, _thread_id}
    end

    test "triggers AI detection for long messages", %{user1: user1, thread: thread} do
      long_text = String.duplicate("This is a long enough chat message for AI detection. ", 3)
      {:ok, _message} = Messaging.send_chat_message(thread.id, user1.id, long_text)
      assert_enqueued(worker: ParkBench.Workers.AITextDetectionWorker)
    end

    test "both users can send messages", %{user1: user1, user2: user2, thread: thread} do
      {:ok, _} = Messaging.send_chat_message(thread.id, user1.id, "From user1")
      {:ok, _} = Messaging.send_chat_message(thread.id, user2.id, "From user2")
      messages = Messaging.list_messages(thread.id)
      assert length(messages) == 2
    end
  end

  describe "mark_chat_read/2" do
    test "marks a thread as read for a user" do
      user1 = insert(:user)
      user2 = insert(:user)
      make_friends(user1, user2)
      {:ok, thread} = Messaging.get_or_create_chat_thread(user1.id, user2.id)

      assert {:ok, _} = Messaging.mark_chat_read(thread.id, user1.id)
    end

    test "fails for non-participant" do
      user1 = insert(:user)
      user2 = insert(:user)
      make_friends(user1, user2)
      {:ok, thread} = Messaging.get_or_create_chat_thread(user1.id, user2.id)
      outsider = insert(:user)

      assert {:error, :not_participant} = Messaging.mark_chat_read(thread.id, outsider.id)
    end
  end

  describe "list_chat_friends_with_threads/1" do
    test "returns friends with thread info" do
      user1 = insert(:user)
      user2 = insert(:user)
      user3 = insert(:user)
      make_friends(user1, user2)
      make_friends(user1, user3)

      {:ok, _thread} = Messaging.get_or_create_chat_thread(user1.id, user2.id)

      results = Messaging.list_chat_friends_with_threads(user1.id)
      assert length(results) == 2

      with_thread = Enum.find(results, &(&1.friend.id == user2.id))
      without_thread = Enum.find(results, &(&1.friend.id == user3.id))

      assert with_thread.thread_id != nil
      assert without_thread.thread_id == nil
    end

    test "returns empty list for user with no friends" do
      user = insert(:user)
      assert Messaging.list_chat_friends_with_threads(user.id) == []
    end
  end

  describe "chat thread shows in inbox" do
    test "chat threads appear in list_inbox" do
      user1 = insert(:user)
      user2 = insert(:user)
      make_friends(user1, user2)
      RateLimiter.reset(user1.id, :send_chat_message)

      {:ok, thread} = Messaging.get_or_create_chat_thread(user1.id, user2.id)
      {:ok, _msg} = Messaging.send_chat_message(thread.id, user1.id, "Hi from chat")

      inbox = Messaging.list_inbox(user1.id)
      assert length(inbox) == 1
      assert hd(inbox).thread.type == "chat"
    end
  end
end
