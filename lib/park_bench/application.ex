defmodule ParkBench.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ParkBenchWeb.Telemetry,
      ParkBench.Repo,
      {DNSCluster, query: Application.get_env(:park_bench, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: ParkBench.PubSub},
      # Circuit breaker registry
      {Registry, keys: :unique, name: ParkBench.AIDetection.CircuitBreakerRegistry},
      # AI Detection infrastructure
      ParkBench.AIDetection.ThresholdServer,
      Supervisor.child_spec({ParkBench.AIDetection.CircuitBreaker, provider: :gptzero},
        id: :cb_gptzero
      ),
      Supervisor.child_spec({ParkBench.AIDetection.CircuitBreaker, provider: :hive},
        id: :cb_hive
      ),
      # Oban background jobs
      {Oban, Application.fetch_env!(:park_bench, Oban)},
      # Chat presence tracking
      ParkBenchWeb.Presence,
      # Start web server last
      ParkBenchWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: ParkBench.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    ParkBenchWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
