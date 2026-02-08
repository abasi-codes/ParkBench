defmodule ParkBench.Workers.ContentRecheckWorker do
  @moduledoc "Re-scans content that was auto-approved during API outage"
  use Oban.Worker, queue: :ai_detection, max_attempts: 2

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"text" => _} = args}) do
    ParkBench.Workers.AITextDetectionWorker.perform(%Oban.Job{args: args})
  end

  def perform(%Oban.Job{args: %{"image_url" => _} = args}) do
    ParkBench.Workers.AIImageDetectionWorker.perform(%Oban.Job{args: args})
  end
end
