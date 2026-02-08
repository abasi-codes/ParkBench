defmodule Sunporch.AIDetection.CircuitBreaker do
  @moduledoc "Circuit breaker for AI detection API providers"
  use GenServer

  @failure_threshold 5
  @failure_window_ms 60_000
  @recovery_timeout_ms 30_000

  defstruct [:provider, state: :closed, failures: [], last_failure_at: nil, opened_at: nil]

  def start_link(opts) do
    provider = Keyword.fetch!(opts, :provider)
    GenServer.start_link(__MODULE__, provider, name: via(provider))
  end

  def call(provider, fun) when is_function(fun, 0) do
    case get_state(provider) do
      :open ->
        {:error, :circuit_open}

      :half_open ->
        try do
          result = fun.()
          GenServer.cast(via(provider), :success)
          result
        rescue
          e ->
            GenServer.cast(via(provider), :failure)
            {:error, {:api_error, e}}
        end

      :closed ->
        try do
          result = fun.()
          GenServer.cast(via(provider), :success)
          result
        rescue
          e ->
            GenServer.cast(via(provider), :failure)
            {:error, {:api_error, e}}
        end
    end
  end

  def get_state(provider) do
    GenServer.call(via(provider), :get_state)
  end

  defp via(provider), do: {:via, Registry, {Sunporch.AIDetection.CircuitBreakerRegistry, provider}}

  @impl true
  def init(provider) do
    {:ok, %__MODULE__{provider: provider}}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    current_state = compute_state(state)
    {:reply, current_state, state}
  end

  @impl true
  def handle_cast(:success, state) do
    {:noreply, %{state | state: :closed, failures: []}}
  end

  def handle_cast(:failure, state) do
    now = System.monotonic_time(:millisecond)
    window_start = now - @failure_window_ms
    recent_failures = Enum.filter([now | state.failures], &(&1 > window_start))

    new_state = if length(recent_failures) >= @failure_threshold do
      %{state | state: :open, failures: recent_failures, opened_at: now}
    else
      %{state | failures: recent_failures}
    end

    {:noreply, new_state}
  end

  defp compute_state(%{state: :open, opened_at: opened_at}) do
    now = System.monotonic_time(:millisecond)
    if now - opened_at > @recovery_timeout_ms, do: :half_open, else: :open
  end

  defp compute_state(%{state: state}), do: state
end
