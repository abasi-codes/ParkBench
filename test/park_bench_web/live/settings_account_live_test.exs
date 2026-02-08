defmodule ParkBenchWeb.SettingsAccountLiveTest do
  use ParkBenchWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "unauthenticated" do
    test "redirects unauthenticated users to /", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/settings/account")
    end
  end

  describe "authenticated" do
    setup %{conn: conn} do
      register_and_log_in_user(%{conn: conn})
    end

    test "renders account settings page", %{conn: conn, user: user} do
      {:ok, _view, html} = live(conn, ~p"/settings/account")
      assert html =~ "Account Settings"
      assert html =~ user.email
      assert html =~ "Display Name"
      assert html =~ "Change Email"
      assert html =~ "Change Password"
      assert html =~ "Delete Account"
    end

    test "can update display name", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/account")

      view
      |> form("form[phx-submit='update_display_name']", %{display_name: "New Display Name"})
      |> render_submit()

      # Verify the display name was updated in the UI
      html = render(view)
      assert html =~ "New Display Name"
    end

    test "rejects empty display name", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/settings/account")

      view
      |> form("form[phx-submit='update_display_name']", %{display_name: ""})
      |> render_submit()

      # Original name should still be there
      html = render(view)
      assert html =~ user.display_name
    end

    test "can change email with correct password", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/account")

      view
      |> form("form[phx-submit='change_email']", %{
        email: "newemail@example.com",
        current_password: "password123"
      })
      |> render_submit()

      html = render(view)
      assert html =~ "newemail@example.com"
    end

    test "rejects email change with wrong password", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/settings/account")

      view
      |> form("form[phx-submit='change_email']", %{
        email: "newemail@example.com",
        current_password: "wrongpassword"
      })
      |> render_submit()

      # Original email should still be there
      html = render(view)
      assert html =~ user.email
    end

    test "can change password with correct current password", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/settings/account")

      view
      |> form("form[phx-submit='change_password']", %{
        current_password: "password123",
        new_password: "newpassword456",
        new_password_confirmation: "newpassword456"
      })
      |> render_submit()

      # Verify password was actually changed
      assert {:ok, _} = ParkBench.Accounts.authenticate_user(user.email, "newpassword456")
    end

    test "rejects password change with wrong current password", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/settings/account")

      view
      |> form("form[phx-submit='change_password']", %{
        current_password: "wrongpassword",
        new_password: "newpassword456",
        new_password_confirmation: "newpassword456"
      })
      |> render_submit()

      # Old password should still work
      assert {:ok, _} = ParkBench.Accounts.authenticate_user(user.email, "password123")
    end

    test "rejects password change when confirmation doesn't match", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/settings/account")

      view
      |> form("form[phx-submit='change_password']", %{
        current_password: "password123",
        new_password: "newpassword456",
        new_password_confirmation: "differentpassword"
      })
      |> render_submit()

      # Old password should still work
      assert {:ok, _} = ParkBench.Accounts.authenticate_user(user.email, "password123")
    end

    test "rejects account deletion with wrong password", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/settings/account")

      view
      |> form("form[phx-submit='delete_account']", %{password: "wrongpassword"})
      |> render_submit()

      # User should still exist
      assert ParkBench.Accounts.get_user(user.id)
    end
  end
end
