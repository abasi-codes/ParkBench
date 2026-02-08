defmodule SunporchWeb.Admin.ModerationLiveTest do
  use SunporchWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "non-admin" do
    setup %{conn: conn} do
      register_and_log_in_user(%{conn: conn})
    end

    test "redirects non-admin users", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/feed"}}} = live(conn, ~p"/admin/moderation")
    end
  end

  describe "admin" do
    setup %{conn: conn} do
      register_and_log_in_admin(%{conn: conn})
    end

    test "renders empty moderation queue", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/moderation")
      assert html =~ "Moderation Queue"
      assert html =~ "No content pending review"
    end

    test "shows items needing review", %{conn: conn} do
      user = insert(:user, email_verified_at: DateTime.utc_now() |> DateTime.truncate(:second), display_name: "FlaggedUser")
      insert(:detection_result, user: user, status: "needs_review", score: 0.85, provider: "gptzero")

      {:ok, _view, html} = live(conn, ~p"/admin/moderation")
      assert html =~ "FlaggedUser"
      assert html =~ "0.85"
      assert html =~ "Approve"
      assert html =~ "Reject"
    end

    test "approve removes item from queue and updates status", %{conn: conn} do
      user = insert(:user, email_verified_at: DateTime.utc_now() |> DateTime.truncate(:second), display_name: "ReviewUser")
      result = insert(:detection_result, user: user, status: "needs_review", score: 0.75)

      {:ok, view, _html} = live(conn, ~p"/admin/moderation")

      view |> element("button", "Approve") |> render_click()

      # Item should be removed from queue
      html = render(view)
      assert html =~ "No content pending review"

      # Verify status changed in DB
      updated = Sunporch.AIDetection.get_result!(result.id)
      assert updated.status == "approved"
    end

    test "reject removes item from queue and updates status", %{conn: conn} do
      user = insert(:user, email_verified_at: DateTime.utc_now() |> DateTime.truncate(:second), display_name: "RejectUser")
      result = insert(:detection_result, user: user, status: "needs_review", score: 0.9)

      {:ok, view, _html} = live(conn, ~p"/admin/moderation")

      view |> element("button", "Reject") |> render_click()

      html = render(view)
      assert html =~ "No content pending review"

      updated = Sunporch.AIDetection.get_result!(result.id)
      assert updated.status == "hard_rejected"
    end
  end
end
