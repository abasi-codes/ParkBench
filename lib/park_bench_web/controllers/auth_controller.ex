defmodule ParkBenchWeb.AuthController do
  use ParkBenchWeb, :controller

  alias ParkBench.Accounts
  alias ParkBench.Mailer.Email, as: MailerEmail
  alias ParkBench.Mailer

  # ──────────────────────────────────────────────
  # GET / — Landing page or redirect to feed
  # ──────────────────────────────────────────────

  def home(conn, _params) do
    if conn.assigns[:current_user] do
      redirect(conn, to: "/feed")
    else
      stats = ParkBench.AIDetection.detection_stats()
      render(conn, :home, page_title: "Welcome", stats: stats)
    end
  end

  # ──────────────────────────────────────────────
  # POST /guest-login — Log in as demo user
  # ──────────────────────────────────────────────

  def guest_login(conn, _params) do
    case Accounts.get_user_by_email("user1@example.com") do
      nil ->
        conn
        |> put_flash(:error, "Guest account not available. Please run seeds first.")
        |> redirect(to: "/")

      user ->
        ip = conn.remote_ip |> format_ip()
        user_agent = get_req_header(conn, "user-agent") |> List.first()
        {:ok, session_token, _session} = Accounts.create_session(user, ip, user_agent)

        conn
        |> put_session(:session_token, session_token)
        |> configure_session(renew: true)
        |> redirect(to: "/feed")
    end
  end

  # ──────────────────────────────────────────────
  # POST /register — Create account
  # ──────────────────────────────────────────────

  def register(conn, %{"user" => user_params}) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        # Generate email verification token and send email
        {:ok, token} = Accounts.create_email_verification_token(user)

        MailerEmail.verification_email(user, token)
        |> Mailer.deliver()

        # Create session and log in
        ip = conn.remote_ip |> format_ip()
        user_agent = get_req_header(conn, "user-agent") |> List.first()
        {:ok, session_token, _session} = Accounts.create_session(user, ip, user_agent)

        conn
        |> put_session(:session_token, session_token)
        |> configure_session(renew: true)
        |> put_flash(
          :info,
          "Welcome to ParkBench! Please check your email to verify your account."
        )
        |> redirect(to: "/onboarding/welcome")

      {:error, changeset} ->
        stats = ParkBench.AIDetection.detection_stats()

        conn
        |> put_flash(:error, error_messages_from_changeset(changeset))
        |> render(:home, page_title: "Welcome", changeset: changeset, stats: stats)
    end
  end

  # ──────────────────────────────────────────────
  # POST /login — Authenticate and create session
  # ──────────────────────────────────────────────

  def login(conn, %{"email" => email, "password" => password}) do
    case Accounts.authenticate_user(email, password) do
      {:ok, user} ->
        ip = conn.remote_ip |> format_ip()
        user_agent = get_req_header(conn, "user-agent") |> List.first()
        {:ok, session_token, _session} = Accounts.create_session(user, ip, user_agent)

        conn
        |> put_session(:session_token, session_token)
        |> configure_session(renew: true)
        |> redirect(to: "/feed")

      {:error, :account_locked} ->
        conn
        |> put_flash(
          :error,
          "Your account has been temporarily locked due to too many failed login attempts. Please try again later."
        )
        |> redirect(to: "/")

      {:error, :invalid_credentials} ->
        conn
        |> put_flash(:error, "Invalid email or password.")
        |> redirect(to: "/")
    end
  end

  # ──────────────────────────────────────────────
  # POST /logout — Delete session, clear cookie
  # ──────────────────────────────────────────────

  def logout(conn, _params) do
    session_token = get_session(conn, :session_token)

    if session_token do
      Accounts.delete_session(session_token)
    end

    conn
    |> configure_session(drop: true)
    |> redirect(to: "/")
  end

  # ──────────────────────────────────────────────
  # GET /verify-email/:token — Verify email address
  # ──────────────────────────────────────────────

  def verify_email(conn, %{"token" => token}) do
    case Accounts.verify_email(token) do
      {:ok, _user} ->
        conn
        |> put_flash(:info, "Your email has been verified! Welcome to ParkBench.")
        |> redirect(to: "/feed")

      {:error, :invalid_token} ->
        conn
        |> put_flash(
          :error,
          "This verification link is invalid or has expired. Please request a new one."
        )
        |> redirect(to: "/")
    end
  end

  # ──────────────────────────────────────────────
  # POST /forgot-password — Request password reset
  # ──────────────────────────────────────────────

  def forgot_password(conn, %{"email" => email}) do
    case Accounts.create_password_reset_token(email) do
      {:ok, :noop} ->
        # User does not exist; respond identically to prevent enumeration
        conn
        |> put_flash(
          :info,
          "If that email is in our system, you will receive password reset instructions shortly."
        )
        |> redirect(to: "/")

      {:ok, token} ->
        user = Accounts.get_user_by_email(email)

        MailerEmail.password_reset_email(user, token)
        |> Mailer.deliver()

        conn
        |> put_flash(
          :info,
          "If that email is in our system, you will receive password reset instructions shortly."
        )
        |> redirect(to: "/")

      {:error, _reason} ->
        conn
        |> put_flash(:error, "Something went wrong. Please try again.")
        |> redirect(to: "/")
    end
  end

  # ──────────────────────────────────────────────
  # GET /reset-password/:token — Show reset form
  # ──────────────────────────────────────────────

  def show_reset_password(conn, %{"token" => token}) do
    render(conn, :reset_password, token: token, page_title: "Reset Password")
  end

  # ──────────────────────────────────────────────
  # POST /reset-password/:token — Perform reset
  # ──────────────────────────────────────────────

  def reset_password(conn, %{
        "token" => token,
        "password" => password,
        "password_confirmation" => password_confirmation
      }) do
    case Accounts.reset_password(token, password, password_confirmation) do
      {:ok, _user} ->
        conn
        |> put_flash(:info, "Your password has been reset. Please log in with your new password.")
        |> redirect(to: "/")

      {:error, :invalid_token} ->
        conn
        |> put_flash(
          :error,
          "This password reset link is invalid or has expired. Please request a new one."
        )
        |> redirect(to: "/")

      {:error, _reason} ->
        conn
        |> put_flash(
          :error,
          "Could not reset password. Please ensure your password meets the requirements and try again."
        )
        |> redirect(to: "/reset-password/#{token}")
    end
  end

  # ──────────────────────────────────────────────
  # Private helpers
  # ──────────────────────────────────────────────

  defp format_ip({a, b, c, d}), do: "#{a}.#{b}.#{c}.#{d}"

  defp format_ip({a, b, c, d, e, f, g, h}) do
    [a, b, c, d, e, f, g, h]
    |> Enum.map_join(":", &Integer.to_string(&1, 16))
  end

  defp format_ip(_), do: nil

  defp error_messages_from_changeset(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
    |> Enum.map_join("; ", fn {field, messages} ->
      "#{Phoenix.Naming.humanize(field)} #{Enum.join(messages, ", ")}"
    end)
  end
end
