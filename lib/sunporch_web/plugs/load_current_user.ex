defmodule SunporchWeb.Plugs.LoadCurrentUser do
  @moduledoc "Reads session cookie and assigns current_user"
  import Plug.Conn
  alias Sunporch.Accounts

  def init(opts), do: opts

  def call(conn, _opts) do
    token = get_session(conn, :session_token)

    cond do
      conn.assigns[:current_user] ->
        conn

      is_nil(token) ->
        assign(conn, :current_user, nil)

      true ->
        case Accounts.get_user_by_session_token(token) do
          nil ->
            conn
            |> delete_session(:session_token)
            |> assign(:current_user, nil)

          user ->
            assign(conn, :current_user, user)
        end
    end
  end
end
