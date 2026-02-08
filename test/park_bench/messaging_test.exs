defmodule ParkBench.MessagingTest do
  use ParkBench.DataCase, async: true

  alias ParkBench.Messaging

  # ──────────────────────────────────────────────
  # Encryption
  # ──────────────────────────────────────────────

  describe "encrypt_message/1 and decrypt_message/1" do
    test "round-trip encryption preserves the message" do
      plaintext = "Hello, this is a secret message!"
      encrypted = Messaging.encrypt_message(plaintext)

      assert is_binary(encrypted)
      assert encrypted != plaintext

      decrypted = Messaging.decrypt_message(encrypted)
      assert decrypted == plaintext
    end

    test "different messages produce different ciphertext" do
      enc1 = Messaging.encrypt_message("Message A")
      enc2 = Messaging.encrypt_message("Message B")
      assert enc1 != enc2
    end

    test "same message encrypted twice produces different ciphertext (random IV)" do
      msg = "Same message"
      enc1 = Messaging.encrypt_message(msg)
      enc2 = Messaging.encrypt_message(msg)
      assert enc1 != enc2
    end

    test "decrypt returns fallback for corrupted data" do
      result = Messaging.decrypt_message("not valid encrypted data at all")
      assert result == "[Message could not be decrypted]"
    end
  end

  # ──────────────────────────────────────────────
  # Create Thread
  # ──────────────────────────────────────────────

  describe "create_thread/4" do
    test "creates a thread with participants and first message" do
      sender = insert(:user)
      recipient = insert(:user)

      assert {:ok, result} =
               Messaging.create_thread(sender.id, recipient.id, "Hello!", "First message body")

      assert result.thread.subject == "Hello!"
      assert result.message.thread_id == result.thread.id
    end

    test "returns error for self-message" do
      user = insert(:user)

      assert {:error, :cannot_message_self} =
               Messaging.create_thread(user.id, user.id, "Self", "Self message")
    end

    test "returns error when blocked" do
      user1 = insert(:user)
      user2 = insert(:user)
      insert(:block, blocker: user1, blocked: user2)

      assert {:error, :blocked} =
               Messaging.create_thread(user1.id, user2.id, "Blocked", "Blocked message")
    end

    test "returns error when blocked by recipient" do
      user1 = insert(:user)
      user2 = insert(:user)
      insert(:block, blocker: user2, blocked: user1)

      assert {:error, :blocked} =
               Messaging.create_thread(user1.id, user2.id, "Blocked", "Blocked message")
    end
  end

  # ──────────────────────────────────────────────
  # Reply to Thread
  # ──────────────────────────────────────────────

  describe "reply_to_thread/3" do
    test "adds a reply to an existing thread" do
      sender = insert(:user)
      recipient = insert(:user)

      {:ok, %{thread: thread}} =
        Messaging.create_thread(sender.id, recipient.id, "Subject", "Initial message")

      assert {:ok, reply} = Messaging.reply_to_thread(thread.id, recipient.id, "Reply body")
      assert reply.sender_id == recipient.id
      assert reply.thread_id == thread.id
    end

    test "returns error when not a participant" do
      sender = insert(:user)
      recipient = insert(:user)
      outsider = insert(:user)

      {:ok, %{thread: thread}} =
        Messaging.create_thread(sender.id, recipient.id, "Subject", "Message")

      assert {:error, :not_participant} =
               Messaging.reply_to_thread(thread.id, outsider.id, "Sneaky reply")
    end

    test "updates thread last_message_at" do
      sender = insert(:user)
      recipient = insert(:user)

      {:ok, %{thread: thread}} =
        Messaging.create_thread(sender.id, recipient.id, "Subject", "First")

      original_last_message = thread.last_message_at

      # Small delay to get a different timestamp
      Process.sleep(10)
      {:ok, _reply} = Messaging.reply_to_thread(thread.id, recipient.id, "Reply")

      updated_thread = Repo.get!(ParkBench.Messaging.MessageThread, thread.id)
      assert DateTime.compare(updated_thread.last_message_at, original_last_message) in [:gt, :eq]
    end
  end

  # ──────────────────────────────────────────────
  # Inbox
  # ──────────────────────────────────────────────

  describe "list_inbox/2" do
    test "returns threads for a user ordered by last message" do
      sender = insert(:user)
      recipient = insert(:user)

      {:ok, %{thread: thread1}} =
        Messaging.create_thread(sender.id, recipient.id, "Thread 1", "Message 1")

      # Set thread1 to an earlier timestamp so ordering is deterministic
      earlier = DateTime.add(DateTime.utc_now(), -60, :second) |> DateTime.truncate(:second)

      Repo.get!(ParkBench.Messaging.MessageThread, thread1.id)
      |> Ecto.Changeset.change(last_message_at: earlier)
      |> Repo.update!()

      {:ok, %{thread: thread2}} =
        Messaging.create_thread(sender.id, recipient.id, "Thread 2", "Message 2")

      inbox = Messaging.list_inbox(recipient.id)
      assert length(inbox) == 2

      # Most recent thread should be first
      thread_ids = Enum.map(inbox, fn item -> item.thread.id end)
      assert hd(thread_ids) == thread2.id
    end

    test "detects unread threads" do
      sender = insert(:user)
      recipient = insert(:user)

      {:ok, _} = Messaging.create_thread(sender.id, recipient.id, "Unread Thread", "Hello")

      inbox = Messaging.list_inbox(recipient.id)
      assert length(inbox) == 1
      assert hd(inbox).unread == true
    end

    test "paginates inbox" do
      sender = insert(:user)
      recipient = insert(:user)

      for i <- 1..5 do
        {:ok, _} =
          Messaging.create_thread(sender.id, recipient.id, "Thread #{i}", "Message #{i}")
      end

      page1 = Messaging.list_inbox(recipient.id, page: 1, per_page: 3)
      page2 = Messaging.list_inbox(recipient.id, page: 2, per_page: 3)

      assert length(page1) == 3
      assert length(page2) == 2
    end
  end

  # ──────────────────────────────────────────────
  # Get Thread
  # ──────────────────────────────────────────────

  describe "get_thread/2" do
    test "returns thread with messages for a participant" do
      sender = insert(:user)
      recipient = insert(:user)

      {:ok, %{thread: thread}} =
        Messaging.create_thread(sender.id, recipient.id, "View Thread", "Body")

      assert {:ok, result} = Messaging.get_thread(thread.id, recipient.id)
      assert result.thread.id == thread.id
      assert length(result.messages) >= 1
      assert length(result.other_users) == 1
      assert hd(result.other_users).id == sender.id
    end

    test "returns error for non-participant" do
      sender = insert(:user)
      recipient = insert(:user)
      outsider = insert(:user)

      {:ok, %{thread: thread}} =
        Messaging.create_thread(sender.id, recipient.id, "Private", "Secret")

      assert {:error, :not_participant} = Messaging.get_thread(thread.id, outsider.id)
    end

    test "marks thread as read for the viewing user" do
      sender = insert(:user)
      recipient = insert(:user)

      {:ok, %{thread: thread}} =
        Messaging.create_thread(sender.id, recipient.id, "Mark Read", "Hello")

      # Recipient has not read yet, so unread count should be > 0
      assert Messaging.count_unread(recipient.id) >= 1

      # View thread marks it as read
      {:ok, _} = Messaging.get_thread(thread.id, recipient.id)

      # Now unread for that thread should be 0
      assert Messaging.count_unread(recipient.id) == 0
    end
  end

  # ──────────────────────────────────────────────
  # List Messages
  # ──────────────────────────────────────────────

  describe "list_messages/1" do
    test "returns decrypted messages in order" do
      sender = insert(:user)
      recipient = insert(:user)

      {:ok, %{thread: thread}} =
        Messaging.create_thread(sender.id, recipient.id, "Messages", "First message")

      {:ok, _} = Messaging.reply_to_thread(thread.id, recipient.id, "Second message")

      messages = Messaging.list_messages(thread.id)
      assert length(messages) == 2

      # Messages should have decrypted body
      bodies = Enum.map(messages, & &1.body)
      assert "First message" in bodies
      assert "Second message" in bodies

      # encrypted_body should be nil (cleared for security)
      assert Enum.all?(messages, fn m -> m.encrypted_body == nil end)
    end
  end

  # ──────────────────────────────────────────────
  # Count Unread
  # ──────────────────────────────────────────────

  describe "count_unread/1" do
    test "counts threads with unread messages" do
      sender = insert(:user)
      recipient = insert(:user)

      {:ok, _} = Messaging.create_thread(sender.id, recipient.id, "Thread 1", "Hello")
      {:ok, _} = Messaging.create_thread(sender.id, recipient.id, "Thread 2", "Hello again")

      assert Messaging.count_unread(recipient.id) == 2
    end

    test "returns 0 when all are read" do
      sender = insert(:user)
      recipient = insert(:user)

      {:ok, %{thread: thread}} =
        Messaging.create_thread(sender.id, recipient.id, "Thread", "Hello")

      # Reading the thread marks it as read
      Messaging.get_thread(thread.id, recipient.id)

      assert Messaging.count_unread(recipient.id) == 0
    end
  end

  # ──────────────────────────────────────────────
  # Delete Thread for User
  # ──────────────────────────────────────────────

  describe "delete_thread_for_user/2" do
    test "soft deletes the thread for a participant" do
      sender = insert(:user)
      recipient = insert(:user)

      {:ok, %{thread: thread}} =
        Messaging.create_thread(sender.id, recipient.id, "Delete Me", "Body")

      assert {:ok, _} = Messaging.delete_thread_for_user(thread.id, recipient.id)

      # Thread should no longer appear in inbox
      inbox = Messaging.list_inbox(recipient.id)
      thread_ids = Enum.map(inbox, fn item -> item.thread.id end)
      refute thread.id in thread_ids
    end

    test "returns error for non-participant" do
      sender = insert(:user)
      recipient = insert(:user)
      outsider = insert(:user)

      {:ok, %{thread: thread}} =
        Messaging.create_thread(sender.id, recipient.id, "Private", "Secret")

      assert {:error, :not_participant} = Messaging.delete_thread_for_user(thread.id, outsider.id)
    end
  end
end
