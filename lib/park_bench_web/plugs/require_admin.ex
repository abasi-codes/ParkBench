defmodule ParkBenchWeb.Plugs.RequireAdmin do
  @moduledoc "Ensures the current user has admin or moderator role"
  import Plug.Conn
  import Phoenix.Controller

  def init(opts), do: opts

  def call(conn, _opts) do
    case conn.assigns[:current_user] do
      %{role: role} when role in ["admin", "moderator"] ->
        conn

      _ ->
        conn
        |> put_flash(:error, "You don't have access to this page.")
        |> redirect(to: "/feed")
        |> halt()
    end
  end
end
