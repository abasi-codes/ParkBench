defmodule SunporchWeb.RealtimeMessagingTest do
  use SunporchWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Sunporch.Messaging

  describe "real-time messaging" do
    setup %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      friend = insert(:user, email_verified_at: DateTime.utc_now() |> DateTime.truncate(:second))

      # Make them friends
      {u, f} = if user.id < friend.id, do: {user, friend}, else: {friend, user}
      insert(:friendship, user: u, friend: f)

      %{conn: conn, user: user, friend: friend}
    end

    test "ThreadLive updates messages on thread broadcast", %{conn: conn, user: user, friend: friend} do
      {:ok, %{thread: thread}} = Messaging.create_thread(user.id, friend.id, "Test Thread", "Hello!")

      {:ok, view, html} = live(conn, ~p"/inbox/thread/#{thread.id}")
      assert html =~ "Hello!"

      # Simulate friend replying via broadcast
      Phoenix.PubSub.broadcast(Sunporch.PubSub, "thread:#{thread.id}", {:new_message, %{}})

      # View should reload messages
      html = render(view)
      assert html =~ "Hello!"
    end

    test "ThreadLive shows new message from other user in real-time", %{conn: conn, user: user, friend: friend} do
      {:ok, %{thread: thread}} = Messaging.create_thread(user.id, friend.id, "Chat", "First message")

      {:ok, view, _html} = live(conn, ~p"/inbox/thread/#{thread.id}")

      # Friend sends a reply (this triggers the broadcast)
      {:ok, _msg} = Messaging.reply_to_thread(thread.id, friend.id, "Real-time reply!")

      html = render(view)
      assert html =~ "Real-time reply!"
    end

    test "InboxLive refreshes thread list on new_message broadcast", %{conn: conn, user: user, friend: friend} do
      {:ok, %{thread: _thread}} = Messaging.create_thread(user.id, friend.id, "Inbox Thread", "Hey there")

      {:ok, view, html} = live(conn, ~p"/inbox")
      assert html =~ "Inbox Thread"

      # Broadcast a new message event
      Phoenix.PubSub.broadcast(Sunporch.PubSub, "user:#{user.id}", {:new_message, "some_thread"})

      # Should not crash
      html = render(view)
      assert html =~ "Inbox Thread"
    end

    test "ThreadLive doesn't crash on unknown broadcasts", %{conn: conn, user: user, friend: friend} do
      {:ok, %{thread: thread}} = Messaging.create_thread(user.id, friend.id, "Stable", "Stable msg")

      {:ok, view, _html} = live(conn, ~p"/inbox/thread/#{thread.id}")

      Phoenix.PubSub.broadcast(Sunporch.PubSub, "thread:#{thread.id}", {:unknown_thing, %{}})

      html = render(view)
      assert html =~ "Stable"
    end

    test "InboxLive doesn't crash on unknown broadcasts", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/inbox")

      Phoenix.PubSub.broadcast(Sunporch.PubSub, "user:#{user.id}", {:something_weird, %{}})

      html = render(view)
      assert html =~ "Inbox"
    end

    test "creating thread broadcasts to thread channel", %{user: user, friend: friend} do
      Phoenix.PubSub.subscribe(Sunporch.PubSub, "user:#{friend.id}")

      {:ok, %{thread: thread}} = Messaging.create_thread(user.id, friend.id, "Broadcast Test", "Testing")

      # Should receive the user-level broadcast
      thread_id = thread.id
      assert_receive {:new_message, ^thread_id}, 1000

      # Subscribe to thread channel for future messages
      Phoenix.PubSub.subscribe(Sunporch.PubSub, "thread:#{thread.id}")

      {:ok, _msg} = Messaging.reply_to_thread(thread.id, friend.id, "Reply!")

      assert_receive {:new_message, _message}, 1000
    end
  end
end
