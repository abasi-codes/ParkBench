defmodule ParkBenchWeb.Admin.DashboardLiveTest do
  use ParkBenchWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "unauthenticated" do
    test "redirects unauthenticated users", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/admin")
    end
  end

  describe "non-admin users" do
    setup %{conn: conn} do
      register_and_log_in_user(%{conn: conn})
    end

    test "redirects non-admin users to /feed", %{conn: conn} do
      # The plug pipeline redirects before we get to the live view.
      # Non-admin users get redirected by RequireAdmin plug.
      conn = get(conn, ~p"/admin")
      assert redirected_to(conn) == "/feed"
    end
  end

  describe "admin users" do
    setup %{conn: conn} do
      register_and_log_in_admin(%{conn: conn})
    end

    test "renders admin dashboard for admin users", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin")
      assert html =~ "Admin Dashboard"
      assert html =~ "AI Detection"
      assert html =~ "Total scans"
    end

    test "shows detection stats", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin")
      assert html =~ "Pending"
      assert html =~ "Approved"
      assert html =~ "Rejected"
      assert html =~ "Appeals pending"
    end

    test "shows navigation links to admin subpages", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin")
      assert html =~ "Manage Users"
      assert html =~ "Moderation Queue"
      assert html =~ "Appeals"
      assert html =~ "AI Thresholds"
      assert html =~ ~s|href="/admin/users"|
      assert html =~ ~s|href="/admin/moderation"|
      assert html =~ ~s|href="/admin/appeals"|
      assert html =~ ~s|href="/admin/ai-thresholds"|
    end
  end
end
