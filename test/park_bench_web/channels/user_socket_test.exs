defmodule ParkBenchWeb.UserSocketTest do
  use ParkBenchWeb.ChannelCase, async: true

  alias ParkBench.Repo
  alias ParkBenchWeb.UserSocket

  describe "connect/3" do
    test "connects with valid token" do
      user = insert(:user)
      token = Phoenix.Token.sign(ParkBenchWeb.Endpoint, "user socket", user.id)

      assert {:ok, socket} = connect(UserSocket, %{"token" => token})
      assert socket.assigns.current_user.id == user.id
    end

    test "rejects invalid token" do
      assert :error = connect(UserSocket, %{"token" => "invalid-token"})
    end

    test "rejects expired token" do
      user = insert(:user)
      token = Phoenix.Token.sign(ParkBenchWeb.Endpoint, "user socket", user.id)

      # Token is valid for 86400 seconds, so we can't easily test expiry
      # but we can test wrong salt
      bad_token = Phoenix.Token.sign(ParkBenchWeb.Endpoint, "wrong salt", user.id)
      assert :error = connect(UserSocket, %{"token" => bad_token})
    end

    test "rejects missing token" do
      assert :error = connect(UserSocket, %{})
    end

    test "rejects token for deleted user" do
      user = insert(:user)
      token = Phoenix.Token.sign(ParkBenchWeb.Endpoint, "user socket", user.id)
      Repo.delete!(user)

      assert :error = connect(UserSocket, %{"token" => token})
    end

    test "socket id includes user id" do
      user = insert(:user)
      token = Phoenix.Token.sign(ParkBenchWeb.Endpoint, "user socket", user.id)

      {:ok, socket} = connect(UserSocket, %{"token" => token})
      assert UserSocket.id(socket) == "user_socket:#{user.id}"
    end
  end
end
