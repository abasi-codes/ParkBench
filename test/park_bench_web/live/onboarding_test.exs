defmodule ParkBenchWeb.OnboardingTest do
  use ParkBenchWeb.ConnCase

  import Phoenix.LiveViewTest

  defp log_in_unverified_user(%{conn: conn}) do
    user =
      insert(:user,
        email_verified_at: DateTime.utc_now() |> DateTime.truncate(:second),
        onboarding_completed_at: nil
      )

    conn = log_in_user(conn, user)
    %{conn: conn, user: user}
  end

  describe "OnboardingWelcomeLive" do
    setup %{conn: conn} do
      log_in_unverified_user(%{conn: conn})
    end

    test "renders welcome page for new user", %{conn: conn, user: user} do
      {:ok, _view, html} = live(conn, ~p"/onboarding/welcome")
      assert html =~ "Welcome to ParkBench"
      assert html =~ user.display_name
      assert html =~ "Get Started"
    end

    test "redirects to feed if onboarding already completed", %{conn: conn, user: user} do
      ParkBench.Accounts.mark_onboarding_complete(user)
      assert {:error, {:live_redirect, %{to: "/feed"}}} = live(conn, ~p"/onboarding/welcome")
    end
  end

  describe "OnboardingGuidelinesLive" do
    setup %{conn: conn} do
      log_in_unverified_user(%{conn: conn})
    end

    test "renders guidelines page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/onboarding/guidelines")
      assert html =~ "Community Guidelines"
      assert html =~ "Be Authentic"
      assert html =~ "No AI-Generated Content"
    end

    test "next button is disabled until agreement", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/onboarding/guidelines")
      assert html =~ "disabled"

      # Toggle agree
      html = view |> element("input#agree-guidelines") |> render_click()
      refute html =~ "disabled"
    end

    test "toggle_agree toggles the agreed state", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/onboarding/guidelines")

      # First click - agree
      view |> element("input#agree-guidelines") |> render_click()
      html = render(view)
      refute html =~ ~s(class="btn btn-blue disabled")

      # Second click - disagree
      view |> element("input#agree-guidelines") |> render_click()
      html = render(view)
      assert html =~ "disabled"
    end
  end

  describe "OnboardingPrivacyLive" do
    setup %{conn: conn} do
      log_in_unverified_user(%{conn: conn})
    end

    test "renders privacy settings page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/onboarding/privacy")
      assert html =~ "Privacy Settings"
      assert html =~ "Profile Visibility"
      assert html =~ "Wall Posting"
    end

    test "saves privacy settings and navigates to profile setup", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/onboarding/privacy")

      view
      |> form("form[phx-submit='save_and_continue']", %{
        profile_visibility: "friends",
        bio_visibility: "only_me",
        friend_list_visibility: "friends",
        wall_posting: "friends"
      })
      |> render_submit()

      # Should redirect to profile setup
      assert_redirect(view, "/onboarding/profile-setup")
    end
  end

  describe "OnboardingProfileSetupLive" do
    setup %{conn: conn} do
      log_in_unverified_user(%{conn: conn})
    end

    test "renders profile setup page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/onboarding/profile-setup")
      assert html =~ "Set Up Your Profile"
      assert html =~ "Bio"
      assert html =~ "Hometown"
      assert html =~ "Skip for now"
      assert html =~ "Finish Setup"
    end

    test "skip completes onboarding and redirects to feed", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/onboarding/profile-setup")

      view |> element("button", "Skip for now") |> render_click()

      flash = assert_redirect(view, "/feed")
      assert flash["info"] =~ "Welcome to ParkBench"

      # Verify onboarding is marked complete
      updated_user = ParkBench.Accounts.get_user!(user.id)
      assert updated_user.onboarding_completed_at
    end

    test "finish with profile data completes onboarding", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/onboarding/profile-setup")

      view
      |> form("form[phx-submit='finish']", %{
        bio: "Hello, I am a test user.",
        hometown: "Testville",
        current_city: "Exampletown"
      })
      |> render_submit()

      flash = assert_redirect(view, "/feed")
      assert flash["info"] =~ "Welcome to ParkBench"

      # Verify profile was saved
      profile = ParkBench.Accounts.get_profile(user.id)
      assert profile.bio == "Hello, I am a test user."
      assert profile.hometown == "Testville"
    end
  end
end
