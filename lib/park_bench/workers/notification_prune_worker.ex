defmodule ParkBench.Workers.NotificationPruneWorker do
  @moduledoc "Cron worker: prunes read notifications >30d, all >90d"
  use Oban.Worker, queue: :cleanup

  @impl Oban.Worker
  def perform(_job) do
    case ParkBench.Notifications.prune_old_notifications() do
      {:ok, counts} ->
        require Logger
        Logger.info("Notification prune: #{inspect(counts)}")
        :ok

      error ->
        error
    end
  end
end
