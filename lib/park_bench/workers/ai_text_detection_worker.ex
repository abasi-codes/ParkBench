defmodule ParkBench.Workers.AITextDetectionWorker do
  @moduledoc "Oban worker for async text AI detection via GPTZero"
  use Oban.Worker, queue: :ai_detection, max_attempts: 3

  alias ParkBench.AIDetection
  alias ParkBench.AIDetection.{DetectionResult, CircuitBreaker}
  alias ParkBench.Repo

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{
          "result_id" => result_id,
          "text" => text,
          "user_id" => user_id,
          "content_type" => content_type,
          "content_id" => content_id
        }
      }) do
    provider_module = Application.get_env(:park_bench, :ai_detection)[:text_provider]

    result =
      CircuitBreaker.call(:gptzero, fn ->
        provider_module.detect(text)
      end)

    case result do
      {:ok, %{score: score, raw_response: raw}} ->
        # Apply leniency boost
        user = ParkBench.Accounts.get_user!(user_id)
        adjusted_score = max(0.0, score - user.ai_leniency_boost)
        status = AIDetection.determine_status(adjusted_score, :text)

        detection_result = Repo.get!(DetectionResult, result_id)

        detection_result
        |> DetectionResult.changeset(%{
          score: adjusted_score,
          raw_response: raw,
          status: status
        })
        |> Repo.update!()

        # Update content status
        AIDetection.update_content_status(content_type, content_id, status)

        # Check if user should be flagged
        if status in ["soft_rejected", "hard_rejected"] do
          AIDetection.check_and_flag_user(user_id)
        end

        # Broadcast result to user
        Phoenix.PubSub.broadcast(
          ParkBench.PubSub,
          "ai_detection:#{content_type}:#{content_id}",
          {:detection_complete, %{status: status, score: adjusted_score}}
        )

        :ok

      {:error, :circuit_open} ->
        # API unavailable — approve with needs_review
        detection_result = Repo.get!(DetectionResult, result_id)

        detection_result
        |> DetectionResult.changeset(%{
          status: "needs_review",
          raw_response: %{error: "circuit_open"}
        })
        |> Repo.update!()

        AIDetection.update_content_status(content_type, content_id, "needs_review")

        # Queue re-check
        %{
          result_id: result_id,
          text: text,
          user_id: user_id,
          content_type: content_type,
          content_id: content_id
        }
        |> ParkBench.Workers.ContentRecheckWorker.new(
          scheduled_at: DateTime.add(DateTime.utc_now(), 300, :second)
        )
        |> Oban.insert()

        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end
end
