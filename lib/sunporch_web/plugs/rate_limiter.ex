defmodule SunporchWeb.Plugs.RateLimiter do
  @moduledoc """
  Rate limiting plug using ETS counters.

  ## Options

    * `:action` - atom identifying the action being rate-limited (required)
    * `:limit` - maximum number of requests allowed in the window (required)
    * `:window` - time window in milliseconds (required)

  ## Example

      plug SunporchWeb.Plugs.RateLimiter, action: :login, limit: 10, window: 900_000
  """
  import Plug.Conn

  @table :sunporch_rate_limits

  def init(opts) do
    action = Keyword.fetch!(opts, :action)
    limit = Keyword.fetch!(opts, :limit)
    window = Keyword.fetch!(opts, :window)
    %{action: action, limit: limit, window: window}
  end

  def call(conn, %{action: action, limit: limit, window: window}) do
    ensure_table()
    ip = conn.remote_ip |> format_ip()
    key = {action, ip}
    now = System.monotonic_time(:millisecond)
    window_start = now - window

    # Clean old entries and count recent ones
    entries = case :ets.lookup(@table, key) do
      [{^key, timestamps}] -> Enum.filter(timestamps, &(&1 > window_start))
      [] -> []
    end

    if length(entries) >= limit do
      conn
      |> put_resp_content_type("text/plain")
      |> send_resp(429, "Too many requests. Please try again later.")
      |> halt()
    else
      :ets.insert(@table, {key, [now | entries]})
      conn
    end
  end

  defp ensure_table do
    case :ets.whereis(@table) do
      :undefined -> :ets.new(@table, [:named_table, :public, :set])
      _ -> :ok
    end
  rescue
    ArgumentError -> :ok
  end

  defp format_ip({a, b, c, d}), do: "#{a}.#{b}.#{c}.#{d}"

  defp format_ip({a, b, c, d, e, f, g, h}) do
    [a, b, c, d, e, f, g, h]
    |> Enum.map_join(":", &Integer.to_string(&1, 16))
  end

  defp format_ip(ip) when is_binary(ip), do: ip
  defp format_ip(_), do: "unknown"
end
