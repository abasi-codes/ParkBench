defmodule ParkBenchWeb.PageController do
  use ParkBenchWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
