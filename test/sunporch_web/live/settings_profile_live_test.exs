defmodule SunporchWeb.SettingsProfileLiveTest do
  use SunporchWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "unauthenticated" do
    test "redirects unauthenticated users to /", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/settings/profile")
    end
  end

  describe "authenticated" do
    setup %{conn: conn} do
      register_and_log_in_user(%{conn: conn})
    end

    test "renders profile settings page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/settings/profile")
      assert html =~ "Edit Profile"
      assert html =~ "Bio"
      assert html =~ "Interests"
      assert html =~ "Hometown"
      assert html =~ "Save Changes"
    end

    test "can save profile", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/settings/profile")

      view
      |> form("form[phx-submit='save_profile']", %{
        bio: "Updated bio text",
        interests: "Coding, Reading",
        hometown: "TestCity"
      })
      |> render_submit()

      # Verify profile was saved in DB
      profile = Sunporch.Accounts.get_profile(user.id)
      assert profile.bio == "Updated bio text"
      assert profile.interests == "Coding, Reading"
    end

    test "shows photo upload section", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/settings/profile")
      assert html =~ "Profile Photo"
      assert html =~ "Upload Photo"
    end
  end
end
