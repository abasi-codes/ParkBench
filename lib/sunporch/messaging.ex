defmodule Sunporch.Messaging do
  @moduledoc "Private messaging with AES-256-GCM encryption at rest"

  import Ecto.Query
  alias Sunporch.Repo
  alias Sunporch.Messaging.{MessageThread, MessageThreadParticipant, Message}
  alias Sunporch.Accounts.User
  alias Sunporch.Social
  alias Sunporch.AIDetection
  alias Sunporch.RateLimiter

  # === Encryption Helpers ===

  defp encryption_key do
    key = Application.get_env(:sunporch, :message_encryption_key)
    # Ensure 32 bytes for AES-256
    :crypto.hash(:sha256, key)
  end

  def encrypt_message(plaintext) when is_binary(plaintext) do
    key = encryption_key()
    iv = :crypto.strong_rand_bytes(12)
    {ciphertext, tag} = :crypto.crypto_one_time_aead(:aes_256_gcm, key, iv, plaintext, "", true)
    iv <> tag <> ciphertext
  end

  def decrypt_message(encrypted) when is_binary(encrypted) do
    key = encryption_key()
    <<iv::binary-12, tag::binary-16, ciphertext::binary>> = encrypted

    case :crypto.crypto_one_time_aead(:aes_256_gcm, key, iv, ciphertext, "", tag, false) do
      :error -> "[Message could not be decrypted]"
      plaintext -> plaintext
    end
  rescue
    _ -> "[Message could not be decrypted]"
  end

  # === Threads ===

  def create_thread(sender_id, recipient_id, subject, body) do
    cond do
      sender_id == recipient_id ->
        {:error, :cannot_message_self}

      Social.blocked?(sender_id, recipient_id) ->
        {:error, :blocked}

      RateLimiter.check(sender_id, :create_thread) != :ok ->
        {:error, :rate_limited}

      true ->
        Repo.transaction(fn ->
          # Create thread
          {:ok, thread} =
            %MessageThread{}
            |> MessageThread.changeset(%{
              subject: subject,
              last_message_at: DateTime.utc_now() |> DateTime.truncate(:second)
            })
            |> Repo.insert()

          # Add participants
          for user_id <- [sender_id, recipient_id] do
            %MessageThreadParticipant{}
            |> MessageThreadParticipant.changeset(%{
              thread_id: thread.id,
              user_id: user_id,
              last_read_at: if(user_id == sender_id, do: DateTime.utc_now() |> DateTime.truncate(:second))
            })
            |> Repo.insert!()
          end

          # Create first message
          {:ok, message} =
            %Message{}
            |> Message.changeset(%{
              thread_id: thread.id,
              sender_id: sender_id,
              body: body
            })
            |> Repo.insert()

          AIDetection.check_text(sender_id, "message", message.id, body)

          # Broadcast to recipient
          Phoenix.PubSub.broadcast(Sunporch.PubSub, "user:#{recipient_id}", {:new_message, thread.id})

          # Broadcast to thread channel
          Phoenix.PubSub.broadcast(Sunporch.PubSub, "thread:#{thread.id}", {:new_message, message})

          %{thread: thread, message: message}
        end)
    end
  end

  def reply_to_thread(thread_id, sender_id, body) do
    participant = get_participant(thread_id, sender_id)

    cond do
      is_nil(participant) ->
        {:error, :not_participant}

      RateLimiter.check(sender_id, :reply_to_thread) != :ok ->
        {:error, :rate_limited}

      true ->
        now = DateTime.utc_now() |> DateTime.truncate(:second)

        Repo.transaction(fn ->
          {:ok, message} =
            %Message{}
            |> Message.changeset(%{
              thread_id: thread_id,
              sender_id: sender_id,
              body: body
            })
            |> Repo.insert()

          AIDetection.check_text(sender_id, "message", message.id, body)

          # Update thread last_message_at
          Repo.get!(MessageThread, thread_id)
          |> Ecto.Changeset.change(last_message_at: now)
          |> Repo.update!()

          # Mark as read for sender
          participant
          |> Ecto.Changeset.change(last_read_at: now)
          |> Repo.update!()

          # Broadcast to other participants
          other_participant_ids(thread_id, sender_id)
          |> Enum.each(fn uid ->
            Phoenix.PubSub.broadcast(Sunporch.PubSub, "user:#{uid}", {:new_message, thread_id})
          end)

          # Broadcast to thread channel
          Phoenix.PubSub.broadcast(Sunporch.PubSub, "thread:#{thread_id}", {:new_message, message})

          message
        end)
    end
  end

  # === Inbox ===

  def list_inbox(user_id, opts \\ []) do
    page = Keyword.get(opts, :page, 1)
    per_page = Keyword.get(opts, :per_page, 20)

    MessageThreadParticipant
    |> where([mtp], mtp.user_id == ^user_id and is_nil(mtp.deleted_at))
    |> join(:inner, [mtp], t in MessageThread, on: t.id == mtp.thread_id)
    |> order_by([mtp, t], desc: t.last_message_at)
    |> offset(^((page - 1) * per_page))
    |> limit(^per_page)
    |> select([mtp, t], %{
      thread: t,
      last_read_at: mtp.last_read_at
    })
    |> Repo.all()
    |> Enum.map(fn item ->
      thread = item.thread |> Repo.preload(:participants)
      other_users = load_other_participants(thread.id, user_id)
      last_message = get_last_message(thread.id)
      unread = is_nil(item.last_read_at) or
               (last_message && DateTime.compare(last_message.inserted_at, item.last_read_at) == :gt)

      %{
        thread: thread,
        other_users: other_users,
        last_message: last_message,
        unread: unread
      }
    end)
  end

  def get_thread(thread_id, user_id) do
    participant = get_participant(thread_id, user_id)

    if is_nil(participant) do
      {:error, :not_participant}
    else
      thread = Repo.get!(MessageThread, thread_id)
      messages = list_messages(thread_id)
      other_users = load_other_participants(thread_id, user_id)

      # Mark as read
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      participant |> Ecto.Changeset.change(last_read_at: now) |> Repo.update!()

      {:ok, %{thread: thread, messages: messages, other_users: other_users}}
    end
  end

  def list_messages(thread_id) do
    Message
    |> where([m], m.thread_id == ^thread_id)
    |> order_by([m], asc: m.inserted_at)
    |> preload(:sender)
    |> Repo.all()
    |> Enum.map(fn msg ->
      decrypted = decrypt_message(msg.encrypted_body)
      %{msg | body: decrypted, encrypted_body: nil}
    end)
  end

  def count_unread(user_id) do
    from(mtp in MessageThreadParticipant,
      join: t in MessageThread, on: t.id == mtp.thread_id,
      join: m in Message, on: m.thread_id == t.id,
      where: mtp.user_id == ^user_id,
      where: is_nil(mtp.deleted_at),
      where: is_nil(mtp.last_read_at) or m.inserted_at > mtp.last_read_at,
      where: m.sender_id != ^user_id,
      select: count(fragment("DISTINCT ?", t.id))
    )
    |> Repo.one() || 0
  end

  def delete_thread_for_user(thread_id, user_id) do
    case get_participant(thread_id, user_id) do
      nil -> {:error, :not_participant}
      participant ->
        participant
        |> Ecto.Changeset.change(deleted_at: DateTime.utc_now() |> DateTime.truncate(:second))
        |> Repo.update()
    end
  end

  # === Chat ===

  def get_or_create_chat_thread(user_a_id, user_b_id) do
    cond do
      user_a_id == user_b_id ->
        {:error, :cannot_message_self}

      Social.blocked?(user_a_id, user_b_id) ->
        {:error, :blocked}

      not Social.friends?(user_a_id, user_b_id) ->
        {:error, :not_friends}

      true ->
        # Look for existing chat thread between these two users
        existing =
          from(t in MessageThread,
            where: t.type == "chat",
            join: p1 in MessageThreadParticipant, on: p1.thread_id == t.id and p1.user_id == ^user_a_id,
            join: p2 in MessageThreadParticipant, on: p2.thread_id == t.id and p2.user_id == ^user_b_id,
            limit: 1,
            select: t
          )
          |> Repo.one()

        case existing do
          %MessageThread{} = thread ->
            {:ok, thread}

          nil ->
            now = DateTime.utc_now() |> DateTime.truncate(:second)

            Repo.transaction(fn ->
              {:ok, thread} =
                %MessageThread{}
                |> MessageThread.changeset(%{type: "chat", last_message_at: now})
                |> Repo.insert()

              for uid <- [user_a_id, user_b_id] do
                %MessageThreadParticipant{}
                |> MessageThreadParticipant.changeset(%{thread_id: thread.id, user_id: uid})
                |> Repo.insert!()
              end

              thread
            end)
        end
    end
  end

  def send_chat_message(thread_id, sender_id, body) do
    participant = get_participant(thread_id, sender_id)

    cond do
      is_nil(participant) ->
        {:error, :not_participant}

      RateLimiter.check(sender_id, :send_chat_message) != :ok ->
        {:error, :rate_limited}

      true ->
        now = DateTime.utc_now() |> DateTime.truncate(:second)

        changeset =
          %Message{}
          |> Message.changeset(%{
            thread_id: thread_id,
            sender_id: sender_id,
            body: body
          })

        if not changeset.valid? do
          {:error, changeset}
        else
          Repo.transaction(fn ->
            {:ok, message} = Repo.insert(changeset)

          AIDetection.check_text(sender_id, "message", message.id, body)

          # Update thread last_message_at
          Repo.get!(MessageThread, thread_id)
          |> Ecto.Changeset.change(last_message_at: now)
          |> Repo.update!()

          # Mark as read for sender
          participant
          |> Ecto.Changeset.change(last_read_at: now)
          |> Repo.update!()

          # Broadcast to other participants
          other_participant_ids(thread_id, sender_id)
          |> Enum.each(fn uid ->
            Phoenix.PubSub.broadcast(Sunporch.PubSub, "user:#{uid}", {:new_message, thread_id})
          end)

          # Broadcast to thread channel for real-time chat
          Phoenix.PubSub.broadcast(Sunporch.PubSub, "thread:#{thread_id}", {:new_message, message})

          message
          end)
        end
    end
  end

  def mark_chat_read(thread_id, user_id) do
    case get_participant(thread_id, user_id) do
      nil ->
        {:error, :not_participant}

      participant ->
        now = DateTime.utc_now() |> DateTime.truncate(:second)

        participant
        |> Ecto.Changeset.change(last_read_at: now)
        |> Repo.update()
    end
  end

  def list_chat_friends_with_threads(user_id) do
    friends = Social.list_friends(user_id)

    friend_ids = Enum.map(friends, & &1.id)

    # Get all chat threads for this user
    chat_threads =
      from(t in MessageThread,
        where: t.type == "chat",
        join: p1 in MessageThreadParticipant, on: p1.thread_id == t.id and p1.user_id == ^user_id,
        join: p2 in MessageThreadParticipant, on: p2.thread_id == t.id and p2.user_id != ^user_id,
        where: p2.user_id in ^friend_ids,
        select: %{thread_id: t.id, friend_id: p2.user_id, last_message_at: t.last_message_at, last_read_at: p1.last_read_at}
      )
      |> Repo.all()

    thread_map = Map.new(chat_threads, fn ct -> {ct.friend_id, ct} end)

    Enum.map(friends, fn friend ->
      chat_info = Map.get(thread_map, friend.id)

      %{
        friend: friend,
        thread_id: chat_info && chat_info.thread_id,
        last_message_at: chat_info && chat_info.last_message_at,
        unread: chat_info != nil and
                (is_nil(chat_info.last_read_at) or
                 (chat_info.last_message_at != nil and
                  DateTime.compare(chat_info.last_message_at, chat_info.last_read_at) == :gt))
      }
    end)
  end

  # === Helpers ===

  defp get_participant(thread_id, user_id) do
    MessageThreadParticipant
    |> where([mtp], mtp.thread_id == ^thread_id and mtp.user_id == ^user_id)
    |> Repo.one()
  end

  defp other_participant_ids(thread_id, exclude_user_id) do
    MessageThreadParticipant
    |> where([mtp], mtp.thread_id == ^thread_id and mtp.user_id != ^exclude_user_id)
    |> select([mtp], mtp.user_id)
    |> Repo.all()
  end

  defp load_other_participants(thread_id, user_id) do
    MessageThreadParticipant
    |> where([mtp], mtp.thread_id == ^thread_id and mtp.user_id != ^user_id)
    |> join(:inner, [mtp], u in User, on: u.id == mtp.user_id)
    |> select([mtp, u], u)
    |> Repo.all()
  end

  defp get_last_message(thread_id) do
    Message
    |> where([m], m.thread_id == ^thread_id)
    |> order_by([m], desc: m.inserted_at)
    |> limit(1)
    |> preload(:sender)
    |> Repo.one()
  end
end
