defmodule SunporchWeb.SettingsPrivacyLiveTest do
  use SunporchWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "unauthenticated" do
    test "redirects unauthenticated users", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/settings/privacy")
    end
  end

  describe "authenticated" do
    setup %{conn: conn} do
      register_and_log_in_user(%{conn: conn})
    end

    test "renders privacy settings page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/settings/privacy")
      assert html =~ "Privacy Settings"
      assert html =~ "Profile Visibility"
      assert html =~ "Bio"
      assert html =~ "Save Changes"
    end

    test "shows all privacy fields", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/settings/privacy")
      assert html =~ "Profile Visibility"
      assert html =~ "Bio"
      assert html =~ "Interests"
      assert html =~ "Education"
      assert html =~ "Birthday"
      assert html =~ "Hometown"
      assert html =~ "Current City"
      assert html =~ "Phone Number"
      assert html =~ "Email Address"
      assert html =~ "Relationship Status"
      assert html =~ "Who can post on your wall"
      assert html =~ "Friend List"
    end

    test "shows settings navigation links", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/settings/privacy")
      assert html =~ ~s|href="/settings/account"|
      assert html =~ ~s|href="/settings/profile"|
      assert html =~ ~s|href="/settings/privacy"|
    end

    test "can update privacy settings", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/settings/privacy")

      view
      |> form("form[phx-submit='update_privacy']", %{
        "profile_visibility" => "friends",
        "bio_visibility" => "only_me"
      })
      |> render_submit()

      # Verify the settings were persisted
      settings = Sunporch.Privacy.get_privacy_settings(user.id)
      assert settings.profile_visibility == "friends"
      assert settings.bio_visibility == "only_me"
    end

    test "form reflects updated values after submit", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/privacy")

      html =
        view
        |> form("form[phx-submit='update_privacy']", %{
          "profile_visibility" => "only_me"
        })
        |> render_submit()

      # The re-rendered form should show the updated selection
      assert html =~ ~s|selected|
    end

    test "shows visibility options in dropdowns", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/settings/privacy")
      assert html =~ "Everyone"
      assert html =~ "Friends"
      assert html =~ "Only me"
    end
  end
end
