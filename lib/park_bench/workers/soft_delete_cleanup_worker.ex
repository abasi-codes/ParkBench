defmodule ParkBench.Workers.SoftDeleteCleanupWorker do
  @moduledoc "Cron worker: hard-deletes soft-deleted content older than 30 days"
  use Oban.Worker, queue: :cleanup

  @impl Oban.Worker
  def perform(_job) do
    case ParkBench.Timeline.hard_delete_old_soft_deletes(30) do
      {:ok, counts} ->
        require Logger
        Logger.info("Soft delete cleanup: #{inspect(counts)}")
        :ok

      error ->
        error
    end
  end
end
