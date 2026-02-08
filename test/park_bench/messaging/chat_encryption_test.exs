defmodule ParkBench.Messaging.ChatEncryptionTest do
  use ParkBench.DataCase, async: true

  alias ParkBench.Messaging
  alias ParkBench.RateLimiter

  defp make_friends(user1, user2) do
    {low, high} = if user1.id < user2.id, do: {user1, user2}, else: {user2, user1}
    insert(:friendship, user: low, friend: high)
  end

  describe "chat message encryption round-trip" do
    setup do
      user1 = insert(:user)
      user2 = insert(:user)
      make_friends(user1, user2)
      {:ok, thread} = Messaging.get_or_create_chat_thread(user1.id, user2.id)
      RateLimiter.reset(user1.id, :send_chat_message)
      %{user1: user1, thread: thread}
    end

    test "short message round-trip", %{user1: user1, thread: thread} do
      {:ok, _msg} = Messaging.send_chat_message(thread.id, user1.id, "Hi")
      [msg] = Messaging.list_messages(thread.id)
      assert msg.body == "Hi"
    end

    test "emoji message round-trip", %{user1: user1, thread: thread} do
      body = "Hello! \u{1F600}\u{1F44D}\u{2764}\u{FE0F}"
      {:ok, _msg} = Messaging.send_chat_message(thread.id, user1.id, body)
      [msg] = Messaging.list_messages(thread.id)
      assert msg.body == body
    end

    test "long message round-trip", %{user1: user1, thread: thread} do
      body = String.duplicate("abcdefghij", 500)
      {:ok, _msg} = Messaging.send_chat_message(thread.id, user1.id, body)
      [msg] = Messaging.list_messages(thread.id)
      assert msg.body == body
    end

    test "special characters round-trip", %{user1: user1, thread: thread} do
      body = "<script>alert('xss')</script> & \"quotes\" 'single'"
      {:ok, _msg} = Messaging.send_chat_message(thread.id, user1.id, body)
      [msg] = Messaging.list_messages(thread.id)
      assert msg.body == body
    end

    test "encrypted body differs from plaintext", %{user1: user1, thread: thread} do
      {:ok, msg} = Messaging.send_chat_message(thread.id, user1.id, "Plaintext message")
      db_msg = Repo.get!(ParkBench.Messaging.Message, msg.id)
      assert db_msg.encrypted_body != "Plaintext message"
      assert byte_size(db_msg.encrypted_body) > 0
    end
  end
end
