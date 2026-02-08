defmodule SunporchWeb.PageController do
  use SunporchWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
