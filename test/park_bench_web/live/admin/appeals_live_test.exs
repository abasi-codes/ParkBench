defmodule ParkBenchWeb.Admin.AppealsLiveTest do
  use ParkBenchWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "non-admin" do
    setup %{conn: conn} do
      register_and_log_in_user(%{conn: conn})
    end

    test "redirects non-admin users", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/feed"}}} = live(conn, ~p"/admin/appeals")
    end
  end

  describe "admin" do
    setup %{conn: conn} do
      register_and_log_in_admin(%{conn: conn})
    end

    test "renders empty appeals page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/appeals")
      assert html =~ "AI Detection Appeals"
      assert html =~ "No pending appeals"
    end

    test "shows pending appeals", %{conn: conn} do
      user =
        insert(:user,
          email_verified_at: DateTime.utc_now() |> DateTime.truncate(:second),
          display_name: "AppealUser"
        )

      result = insert(:detection_result, user: user, status: "appealed", score: 0.8)

      insert(:detection_appeal,
        user: user,
        detection_result: result,
        explanation: "I wrote this myself"
      )

      {:ok, _view, html} = live(conn, ~p"/admin/appeals")
      assert html =~ "AppealUser"
      assert html =~ "I wrote this myself"
      assert html =~ "Approve"
      assert html =~ "Deny"
    end

    test "approve appeal removes it from list", %{conn: conn} do
      user = insert(:user, email_verified_at: DateTime.utc_now() |> DateTime.truncate(:second))
      result = insert(:detection_result, user: user, status: "appealed", score: 0.7)
      insert(:detection_appeal, user: user, detection_result: result)

      {:ok, view, _html} = live(conn, ~p"/admin/appeals")

      view |> element("button", "Approve") |> render_click()

      html = render(view)
      assert html =~ "No pending appeals"
    end

    test "deny appeal removes it from list", %{conn: conn} do
      user = insert(:user, email_verified_at: DateTime.utc_now() |> DateTime.truncate(:second))
      result = insert(:detection_result, user: user, status: "appealed", score: 0.7)
      insert(:detection_appeal, user: user, detection_result: result)

      {:ok, view, _html} = live(conn, ~p"/admin/appeals")

      view |> element("button", "Deny") |> render_click()

      html = render(view)
      assert html =~ "No pending appeals"
    end
  end
end
