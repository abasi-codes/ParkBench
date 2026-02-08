defmodule ParkBench.RateLimiter do
  @moduledoc """
  Context-level rate limiter for authenticated actions (LiveView/WebSocket).

  Uses ETS with a sliding window of timestamps, keyed by `{action, user_id}`.
  For HTTP-level rate limiting (by IP), see `ParkBenchWeb.Plugs.RateLimiter`.
  """

  @table :park_bench_user_rate_limits

  @doc """
  Check if an action is within rate limits for a user.

  Returns `:ok` if allowed, `{:error, :rate_limited}` if over the limit.
  """
  def check(user_id, action, opts \\ []) do
    {limit, window} = limits_for(action, opts)
    ensure_table()

    key = {action, user_id}
    now = System.monotonic_time(:millisecond)
    window_start = now - window

    entries =
      case :ets.lookup(@table, key) do
        [{^key, timestamps}] -> Enum.filter(timestamps, &(&1 > window_start))
        [] -> []
      end

    if length(entries) >= limit do
      {:error, :rate_limited}
    else
      :ets.insert(@table, {key, [now | entries]})
      :ok
    end
  end

  @doc "Reset rate limit entries for a user/action pair. Useful in tests."
  def reset(user_id, action) do
    ensure_table()
    :ets.delete(@table, {action, user_id})
    :ok
  end

  # Default limits per action. Can be overridden via opts.
  defp limits_for(action, opts) do
    limit = Keyword.get(opts, :limit)
    window = Keyword.get(opts, :window)

    defaults = %{
      # 10 per 5 min
      create_wall_post: {10, 300_000},
      # 20 per 5 min
      create_comment: {20, 300_000},
      # 5 per 5 min
      create_status_update: {5, 300_000},
      # 5 per 5 min
      create_thread: {5, 300_000},
      # 20 per 5 min
      reply_to_thread: {20, 300_000},
      # 30 per minute (chat is rapid-fire)
      send_chat_message: {30, 60_000},
      # 10 per hour
      send_friend_request: {10, 3_600_000},
      # 10 per 5 min
      poke: {10, 300_000}
    }

    {default_limit, default_window} = Map.get(defaults, action, {20, 300_000})
    {limit || default_limit, window || default_window}
  end

  defp ensure_table do
    case :ets.whereis(@table) do
      :undefined -> :ets.new(@table, [:named_table, :public, :set])
      _ -> :ok
    end
  rescue
    ArgumentError -> :ok
  end
end
