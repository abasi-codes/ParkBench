defmodule SunporchWeb.ComposeMessageLiveTest do
  use SunporchWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "unauthenticated" do
    test "redirects unauthenticated users to /", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/inbox/compose")
    end
  end

  describe "authenticated" do
    setup %{conn: conn} do
      register_and_log_in_user(%{conn: conn})
    end

    test "renders compose message page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/inbox/compose")
      assert html =~ "New Message"
      assert html =~ "send_message"
      assert html =~ "Start typing a name"
    end

    test "does not redirect when sending without recipient", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/inbox/compose")

      view
      |> form("form[phx-submit='send_message']", %{subject: "Hello", body: "Test message"})
      |> render_submit()

      # Should stay on compose page (no redirect)
      html = render(view)
      assert html =~ "New Message"
    end

    test "searches for recipients", %{conn: conn} do
      friend = insert(:user, email_verified_at: DateTime.utc_now() |> DateTime.truncate(:second), display_name: "SearchableUser")

      {:ok, view, _html} = live(conn, ~p"/inbox/compose")

      html = view |> render_keyup("search_recipient", %{"q" => "Searchable"})
      assert html =~ "SearchableUser"
    end

    test "short search query clears results", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/inbox/compose")

      html = view |> render_keyup("search_recipient", %{"q" => "a"})
      refute html =~ "search-result-item"
    end
  end
end
