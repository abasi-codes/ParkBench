defmodule ParkBenchWeb.Plugs.ContentSecurityPolicy do
  @moduledoc "Sets a strict Content-Security-Policy header on every response."
  import Plug.Conn

  @csp [
         "default-src 'self'",
         "script-src 'self'",
         "style-src 'self' 'unsafe-inline'",
         "img-src 'self' data: blob: https://*.amazonaws.com",
         "font-src 'self'",
         "connect-src 'self' wss:",
         "frame-ancestors 'none'",
         "base-uri 'self'",
         "form-action 'self'"
       ]
       |> Enum.join("; ")

  def init(opts), do: opts

  def call(conn, _opts) do
    put_resp_header(conn, "content-security-policy", @csp)
  end
end
