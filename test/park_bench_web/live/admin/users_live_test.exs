defmodule ParkBenchWeb.Admin.UsersLiveTest do
  use ParkBenchWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "non-admin" do
    setup %{conn: conn} do
      register_and_log_in_user(%{conn: conn})
    end

    test "redirects non-admin users", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/feed"}}} = live(conn, ~p"/admin/users")
    end
  end

  describe "admin" do
    setup %{conn: conn} do
      register_and_log_in_admin(%{conn: conn})
    end

    test "renders users page", %{conn: conn, user: admin} do
      {:ok, _view, html} = live(conn, ~p"/admin/users")
      assert html =~ "Users"
      assert html =~ admin.display_name
      assert html =~ admin.email
      assert html =~ "admin"
    end

    test "shows user details in table", %{conn: conn} do
      user =
        insert(:user,
          email_verified_at: DateTime.utc_now() |> DateTime.truncate(:second),
          display_name: "RegularUser",
          ai_flagged: true
        )

      {:ok, _view, html} = live(conn, ~p"/admin/users")
      assert html =~ "RegularUser"
      # ai_flagged
      assert html =~ "Yes"
    end
  end
end
