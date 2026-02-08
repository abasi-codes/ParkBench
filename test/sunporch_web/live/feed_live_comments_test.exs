defmodule SunporchWeb.FeedLiveCommentsTest do
  use SunporchWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "comments on feed posts" do
    setup %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})

      # Create a post on own wall
      {:ok, post} =
        Sunporch.Timeline.create_wall_post(%{
          author_id: user.id,
          wall_owner_id: user.id,
          body: "Post for commenting test"
        })

      %{conn: conn, user: user, post: post}
    end

    test "toggle_comments expands comment section", %{conn: conn, post: post} do
      {:ok, view, _html} = live(conn, ~p"/feed")

      # Click comment button to expand
      html = view |> element("button[phx-click='toggle_comments'][phx-value-id='#{post.id}']") |> render_click()
      assert html =~ "Write a comment"
      assert html =~ "wall-comments"
    end

    test "toggle_comments collapses on second click", %{conn: conn, post: post} do
      {:ok, view, _html} = live(conn, ~p"/feed")

      # Expand
      view |> element("button[phx-click='toggle_comments'][phx-value-id='#{post.id}']") |> render_click()
      # Collapse
      html = view |> element("button[phx-click='toggle_comments'][phx-value-id='#{post.id}']") |> render_click()
      refute html =~ "wall-comment-form"
    end

    test "submit_comment adds a comment", %{conn: conn, post: post, user: user} do
      {:ok, view, _html} = live(conn, ~p"/feed")

      # Expand comments
      view |> element("button[phx-click='toggle_comments'][phx-value-id='#{post.id}']") |> render_click()

      # Submit a comment
      html =
        view
        |> form("form[phx-submit='submit_comment']", %{"post-id" => post.id, body: "Great post!"})
        |> render_submit()

      assert html =~ "Great post!"
      assert html =~ user.display_name
    end

    test "delete_comment removes a comment", %{conn: conn, post: post, user: user} do
      # Create a comment first
      {:ok, comment} =
        Sunporch.Timeline.create_comment(%{
          author_id: user.id,
          commentable_type: "WallPost",
          commentable_id: post.id,
          body: "Comment to delete"
        })

      {:ok, view, _html} = live(conn, ~p"/feed")

      # Expand comments
      view |> element("button[phx-click='toggle_comments'][phx-value-id='#{post.id}']") |> render_click()

      # Should see the comment
      html = render(view)
      assert html =~ "Comment to delete"

      # Delete it
      html = view |> element("button[phx-click='delete_comment'][phx-value-id='#{comment.id}']") |> render_click()
      refute html =~ "Comment to delete"
    end
  end
end
