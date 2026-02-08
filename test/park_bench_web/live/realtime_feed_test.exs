defmodule ParkBenchWeb.RealtimeFeedTest do
  use ParkBenchWeb.ConnCase

  import Phoenix.LiveViewTest

  alias ParkBench.Timeline

  describe "real-time feed" do
    setup %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      friend = insert(:user, email_verified_at: DateTime.utc_now() |> DateTime.truncate(:second))

      # Make them friends
      {u, f} = if user.id < friend.id, do: {user, friend}, else: {friend, user}
      insert(:friendship, user: u, friend: f)

      %{conn: conn, user: user, friend: friend}
    end

    test "FeedLive shows 'New posts available' bar on broadcast", %{conn: conn, user: user} do
      {:ok, view, html} = live(conn, ~p"/feed")
      refute html =~ "New posts available"

      Phoenix.PubSub.broadcast(
        ParkBench.PubSub,
        "feed:#{user.id}",
        {:new_feed_item, Ecto.UUID.generate()}
      )

      html = render(view)
      assert html =~ "New posts available"
    end

    test "clicking refresh reloads feed", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/feed")

      # Trigger new posts available
      Phoenix.PubSub.broadcast(
        ParkBench.PubSub,
        "feed:#{user.id}",
        {:new_feed_item, Ecto.UUID.generate()}
      )

      render(view)

      # Click refresh
      view |> element(".new-posts-bar") |> render_click()

      html = render(view)
      refute html =~ "New posts available"
    end

    test "wall post creation triggers feed broadcast to friends", %{user: user, friend: friend} do
      # Subscribe to friend's feed channel
      Phoenix.PubSub.subscribe(ParkBench.PubSub, "feed:#{friend.id}")

      {:ok, _post} =
        Timeline.create_wall_post(%{
          author_id: user.id,
          wall_owner_id: user.id,
          body: "Broadcasting to friends!"
        })

      assert_receive {:new_feed_item, _post_id}, 1000
    end

    test "status update triggers feed broadcast to friends", %{user: user, friend: friend} do
      Phoenix.PubSub.subscribe(ParkBench.PubSub, "feed:#{friend.id}")

      {:ok, _status} =
        Timeline.create_status_update(%{
          user_id: user.id,
          body: "feeling great"
        })

      assert_receive {:new_feed_item, _id}, 1000
    end

    test "non-friends don't receive broadcast", %{user: user} do
      stranger = insert(:user)

      Phoenix.PubSub.subscribe(ParkBench.PubSub, "feed:#{stranger.id}")

      {:ok, _post} =
        Timeline.create_wall_post(%{
          author_id: user.id,
          wall_owner_id: user.id,
          body: "Only for friends"
        })

      refute_receive {:new_feed_item, _}, 200
    end
  end
end
