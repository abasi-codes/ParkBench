defmodule ParkBenchWeb.Plugs.RequireVerifiedEmail do
  @moduledoc "Ensures the current user has verified their email address."
  import Plug.Conn
  import Phoenix.Controller

  def init(opts), do: opts

  def call(conn, _opts) do
    user = conn.assigns[:current_user]

    cond do
      is_nil(user) ->
        # No user loaded; let RequireAuth handle this
        conn

      is_nil(user.email_verified_at) ->
        conn
        |> put_flash(:error, "Please verify your email address to continue.")
        |> redirect(to: "/verify-email-reminder")
        |> halt()

      true ->
        conn
    end
  end
end
