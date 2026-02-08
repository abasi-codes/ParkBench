defmodule ParkBenchWeb.UserSocket do
  use Phoenix.Socket

  channel "chat:*", ParkBenchWeb.ChatChannel
  channel "presence:lobby", ParkBenchWeb.PresenceChannel

  @impl true
  def connect(%{"token" => token}, socket, _connect_info) do
    case Phoenix.Token.verify(ParkBenchWeb.Endpoint, "user socket", token, max_age: 86_400) do
      {:ok, user_id} ->
        case ParkBench.Accounts.get_user(user_id) do
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
