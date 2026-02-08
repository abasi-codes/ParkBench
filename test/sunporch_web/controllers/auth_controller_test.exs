defmodule SunporchWeb.AuthControllerTest do
  use SunporchWeb.ConnCase

  alias Sunporch.Accounts

  describe "GET / (home)" do
    test "renders landing page with registration and login forms", %{conn: conn} do
      conn = get(conn, ~p"/")
      html = html_response(conn, 200)
      assert html =~ "sunporch"
      assert html =~ "Create a New Account"
      assert html =~ "Sign Up"
      assert html =~ "Remember when social media was just"
      assert html =~ "Log In"
    end

    test "redirects authenticated users to /feed", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      conn = get(conn, ~p"/")
      assert redirected_to(conn) == "/feed"
    end
  end

  describe "POST /register" do
    test "creates user and redirects with valid params", %{conn: conn} do
      params = %{
        "user" => %{
          "display_name" => "Jane Doe",
          "email" => "jane@example.com",
          "password" => "securepassword123",
          "password_confirmation" => "securepassword123"
        }
      }

      conn = post(conn, ~p"/register", params)
      assert redirected_to(conn) == "/onboarding/welcome"

      # Verify user was created
      user = Accounts.get_user_by_email("jane@example.com")
      assert user
      assert user.display_name == "Jane Doe"

      # Verify session was created
      assert get_session(conn, :session_token)
    end

    test "shows errors with invalid params - missing fields", %{conn: conn} do
      params = %{
        "user" => %{
          "display_name" => "",
          "email" => "",
          "password" => "",
          "password_confirmation" => ""
        }
      }

      conn = post(conn, ~p"/register", params)
      html = html_response(conn, 200)
      assert html =~ "Create a New Account"
    end

    test "shows errors with mismatched password confirmation", %{conn: conn} do
      params = %{
        "user" => %{
          "display_name" => "Jane Doe",
          "email" => "jane@example.com",
          "password" => "securepassword123",
          "password_confirmation" => "differentpassword"
        }
      }

      conn = post(conn, ~p"/register", params)
      html = html_response(conn, 200)
      assert html =~ "Create a New Account"
    end

    test "shows errors with duplicate email", %{conn: conn} do
      insert(:user, email: "taken@example.com")

      params = %{
        "user" => %{
          "display_name" => "Jane Doe",
          "email" => "taken@example.com",
          "password" => "securepassword123",
          "password_confirmation" => "securepassword123"
        }
      }

      conn = post(conn, ~p"/register", params)
      html = html_response(conn, 200)
      assert html =~ "Create a New Account"
    end
  end

  describe "POST /login" do
    test "redirects to /feed with valid credentials", %{conn: conn} do
      user =
        insert(:user,
          email: "alice@example.com",
          email_verified_at: DateTime.utc_now() |> DateTime.truncate(:second)
        )

      conn = post(conn, ~p"/login", %{"email" => user.email, "password" => "password123"})
      assert redirected_to(conn) == "/feed"
      assert get_session(conn, :session_token)
    end

    test "redirects to / with error for invalid credentials", %{conn: conn} do
      insert(:user, email: "alice@example.com")

      conn = post(conn, ~p"/login", %{"email" => "alice@example.com", "password" => "wrongpassword"})
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Invalid email or password"
    end

    test "redirects to / with error for nonexistent email", %{conn: conn} do
      conn = post(conn, ~p"/login", %{"email" => "nobody@example.com", "password" => "password123"})
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Invalid email or password"
    end
  end

  describe "POST /logout" do
    test "clears session and redirects to /", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      conn = post(conn, ~p"/logout")
      assert redirected_to(conn) == "/"
      # The session is dropped via configure_session(drop: true)
      assert conn.private[:plug_session_info] == :drop
    end

    test "works even when not logged in", %{conn: conn} do
      conn = post(conn, ~p"/logout")
      assert redirected_to(conn) == "/"
    end
  end

  describe "GET /verify-email/:token" do
    test "verifies email with valid token", %{conn: conn} do
      user = insert(:user, email_verified_at: nil)
      {:ok, token} = Accounts.create_email_verification_token(user)

      conn = get(conn, ~p"/verify-email/#{token}")
      assert redirected_to(conn) == "/feed"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "verified"

      # Verify user is now email-verified
      updated_user = Accounts.get_user!(user.id)
      assert updated_user.email_verified_at
    end

    test "shows error with invalid token", %{conn: conn} do
      conn = get(conn, ~p"/verify-email/invalid-token-abc123")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "invalid or has expired"
    end

    test "shows error with already-used token", %{conn: conn} do
      user = insert(:user, email_verified_at: nil)
      {:ok, token} = Accounts.create_email_verification_token(user)

      # Use it once
      get(conn, ~p"/verify-email/#{token}")

      # Try to use it again
      conn = get(conn, ~p"/verify-email/#{token}")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "invalid or has expired"
    end
  end
end
