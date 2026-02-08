defmodule Sunporch.Workers.AIImageDetectionWorker do
  @moduledoc "Oban worker for async image AI detection via Hive"
  use Oban.Worker, queue: :ai_detection, max_attempts: 3

  alias Sunporch.AIDetection
  alias Sunporch.AIDetection.{DetectionResult, CircuitBreaker}
  alias Sunporch.Repo

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"result_id" => result_id, "image_url" => image_url, "user_id" => user_id, "content_type" => content_type, "content_id" => content_id}}) do
    provider_module = Application.get_env(:sunporch, :ai_detection)[:image_provider]

    result = CircuitBreaker.call(:hive, fn ->
      provider_module.detect(image_url)
    end)

    case result do
      {:ok, %{score: score, raw_response: raw}} ->
        user = Sunporch.Accounts.get_user!(user_id)
        adjusted_score = max(0.0, score - user.ai_leniency_boost)
        status = AIDetection.determine_status(adjusted_score, :image)

        detection_result = Repo.get!(DetectionResult, result_id)
        detection_result
        |> DetectionResult.changeset(%{
          score: adjusted_score,
          raw_response: raw,
          status: status
        })
        |> Repo.update!()

        AIDetection.update_content_status(content_type, content_id, status)

        if status in ["soft_rejected", "hard_rejected"] do
          AIDetection.check_and_flag_user(user_id)
        end

        Phoenix.PubSub.broadcast(
          Sunporch.PubSub,
          "ai_detection:#{content_type}:#{content_id}",
          {:detection_complete, %{status: status, score: adjusted_score}}
        )

        :ok

      {:error, :circuit_open} ->
        detection_result = Repo.get!(DetectionResult, result_id)
        detection_result
        |> DetectionResult.changeset(%{status: "needs_review", raw_response: %{error: "circuit_open"}})
        |> Repo.update!()

        AIDetection.update_content_status(content_type, content_id, "needs_review")

        %{result_id: result_id, image_url: image_url, user_id: user_id, content_type: content_type, content_id: content_id}
        |> Sunporch.Workers.ContentRecheckWorker.new(scheduled_at: DateTime.add(DateTime.utc_now(), 300, :second))
        |> Oban.insert()

        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end
end
