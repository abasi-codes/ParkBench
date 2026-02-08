defmodule ParkBenchWeb.AuthHelpers do
  @moduledoc "Test helpers for authentication in controller and LiveView tests."

  import ParkBench.Factory
  alias ParkBench.Accounts

  def register_and_log_in_user(%{conn: conn}) do
    user = insert(:user, email_verified_at: DateTime.utc_now() |> DateTime.truncate(:second))
    conn = log_in_user(conn, user)
    %{conn: conn, user: user}
  end

  def register_and_log_in_admin(%{conn: conn}) do
    user =
      insert(:user,
        email_verified_at: DateTime.utc_now() |> DateTime.truncate(:second),
        role: "admin"
      )

    conn = log_in_user(conn, user)
    %{conn: conn, user: user}
  end

  def log_in_user(conn, user) do
    {:ok, token, _session} = Accounts.create_session(user)
    conn |> Plug.Test.init_test_session(%{session_token: token})
  end
end
