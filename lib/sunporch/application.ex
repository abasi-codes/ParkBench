defmodule Sunporch.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      SunporchWeb.Telemetry,
      Sunporch.Repo,
      {DNSCluster, query: Application.get_env(:sunporch, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Sunporch.PubSub},
      # Circuit breaker registry
      {Registry, keys: :unique, name: Sunporch.AIDetection.CircuitBreakerRegistry},
      # AI Detection infrastructure
      Sunporch.AIDetection.ThresholdServer,
      Supervisor.child_spec({Sunporch.AIDetection.CircuitBreaker, provider: :gptzero}, id: :cb_gptzero),
      Supervisor.child_spec({Sunporch.AIDetection.CircuitBreaker, provider: :hive}, id: :cb_hive),
      # Oban background jobs
      {Oban, Application.fetch_env!(:sunporch, Oban)},
      # Chat presence tracking
      SunporchWeb.Presence,
      # Start web server last
      SunporchWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: Sunporch.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    SunporchWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
