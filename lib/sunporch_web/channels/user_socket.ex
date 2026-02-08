defmodule SunporchWeb.UserSocket do
  use Phoenix.Socket

  channel "chat:*", SunporchWeb.ChatChannel
  channel "presence:lobby", SunporchWeb.PresenceChannel

  @impl true
  def connect(%{"token" => token}, socket, _connect_info) do
    case Phoenix.Token.verify(SunporchWeb.Endpoint, "user socket", token, max_age: 86_400) do
      {:ok, user_id} ->
        case Sunporch.Accounts.get_user(user_id) do
          nil -> :error
          user -> {:ok, assign(socket, :current_user, user)}
        end

      {:error, _reason} ->
        :error
    end
  end

  def connect(_params, _socket, _connect_info), do: :error

  @impl true
  def id(socket), do: "user_socket:#{socket.assigns.current_user.id}"
end
