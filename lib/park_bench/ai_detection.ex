defmodule ParkBench.AIDetection do
  @moduledoc "AI content detection pipeline — GPTZero for text, Hive for images"

  import Ecto.Query
  alias ParkBench.Repo
  alias ParkBench.AIDetection.{DetectionResult, DetectionAppeal, ThresholdServer}

  @min_text_length 50

  # === Detection Entry Points ===

  def check_text(user_id, content_type, content_id, text) do
    if String.length(text) < @min_text_length do
      create_result(%{
        user_id: user_id,
        content_type: content_type,
        content_id: content_id,
        provider: "exempt",
        score: 0.0,
        status: "approved",
        content_hash: hash_content(text),
        raw_response: %{reason: "below_minimum_length"}
      })
    else
      content_hash = hash_content(text)

      case get_recent_approved_by_hash(content_hash) do
        %{score: score, id: cached_id} ->
          create_result(%{
            user_id: user_id,
            content_type: content_type,
            content_id: content_id,
            provider: "cache",
            score: score,
            status: "approved",
            content_hash: content_hash,
            raw_response: %{cached_from: cached_id}
          })

        nil ->
          enqueue_text_detection(user_id, content_type, content_id, text, content_hash)
      end
    end
  end

  def check_image(user_id, content_type, content_id, image_url) do
    content_hash = hash_content(image_url)

    case get_recent_approved_by_hash(content_hash) do
      %{} ->
        create_result(%{
          user_id: user_id,
          content_type: content_type,
          content_id: content_id,
          provider: "cache",
          score: 0.0,
          status: "approved",
          content_hash: content_hash,
          raw_response: %{cached: true}
        })

      nil ->
        enqueue_image_detection(user_id, content_type, content_id, image_url, content_hash)
    end
  end

  # === Results ===

  def create_result(attrs) do
    %DetectionResult{}
    |> DetectionResult.changeset(attrs)
    |> Repo.insert()
  end

  def get_result(content_type, content_id) do
    DetectionResult
    |> where([r], r.content_type == ^content_type and r.content_id == ^content_id)
    |> order_by([r], desc: r.inserted_at)
    |> limit(1)
    |> Repo.one()
  end

  def get_result!(id), do: Repo.get!(DetectionResult, id)

  def update_detection_status(result_id, new_status) do
    result = get_result!(result_id)

    result
    |> DetectionResult.changeset(%{status: new_status})
    |> Repo.update()
    |> case do
      {:ok, updated} ->
        update_content_status(updated.content_type, updated.content_id, new_status)
        {:ok, updated}

      error ->
        error
    end
  end

  def determine_status(score, type) do
    thresholds = get_thresholds()

    {soft, hard} =
      case type do
        :text -> {thresholds.text_soft_reject, thresholds.text_hard_reject}
        :image -> {thresholds.image_soft_reject, thresholds.image_hard_reject}
      end

    cond do
      score >= hard -> "hard_rejected"
      score >= soft -> "soft_rejected"
      true -> "approved"
    end
  end

  def get_thresholds do
    case ThresholdServer.get_thresholds() do
      nil -> default_thresholds()
      thresholds -> thresholds
    end
  end

  def update_thresholds(attrs) do
    ThresholdServer.update_thresholds(attrs)
  end

  defp default_thresholds do
    config = Application.get_env(:park_bench, :ai_detection, [])

    %{
      text_soft_reject: Keyword.get(config, :text_soft_reject, 0.65),
      text_hard_reject: Keyword.get(config, :text_hard_reject, 0.85),
      image_soft_reject: Keyword.get(config, :image_soft_reject, 0.70),
      image_hard_reject: Keyword.get(config, :image_hard_reject, 0.90)
    }
  end

  # === Cache / Dedup ===

  defp get_recent_approved_by_hash(hash) do
    one_hour_ago = DateTime.add(DateTime.utc_now(), -3600, :second)

    DetectionResult
    |> where([r], r.content_hash == ^hash and r.status == "approved")
    |> where([r], r.inserted_at > ^one_hour_ago)
    |> limit(1)
    |> Repo.one()
  end

  defp hash_content(content) do
    :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)
  end

  # === Enqueue Workers ===

  defp enqueue_text_detection(user_id, content_type, content_id, text, content_hash) do
    # Create a pending result first
    {:ok, result} =
      create_result(%{
        user_id: user_id,
        content_type: content_type,
        content_id: content_id,
        provider: "gptzero",
        score: 0.0,
        status: "pending",
        content_hash: content_hash,
        raw_response: %{}
      })

    # Enqueue Oban job
    %{
      result_id: result.id,
      text: text,
      user_id: user_id,
      content_type: content_type,
      content_id: content_id
    }
    |> ParkBench.Workers.AITextDetectionWorker.new()
    |> Oban.insert()

    {:ok, result}
  end

  defp enqueue_image_detection(user_id, content_type, content_id, image_url, content_hash) do
    {:ok, result} =
      create_result(%{
        user_id: user_id,
        content_type: content_type,
        content_id: content_id,
        provider: "hive",
        score: 0.0,
        status: "pending",
        content_hash: content_hash,
        raw_response: %{}
      })

    %{
      result_id: result.id,
      image_url: image_url,
      user_id: user_id,
      content_type: content_type,
      content_id: content_id
    }
    |> ParkBench.Workers.AIImageDetectionWorker.new()
    |> Oban.insert()

    {:ok, result}
  end

  # === Update content status after detection ===

  def update_content_status(content_type, content_id, status) do
    case content_type do
      "wall_post" ->
        ParkBench.Timeline.WallPost
        |> where([p], p.id == ^content_id)
        |> Repo.update_all(set: [ai_detection_status: status])

      "comment" ->
        ParkBench.Timeline.Comment
        |> where([c], c.id == ^content_id)
        |> Repo.update_all(set: [ai_detection_status: status])

      "status_update" ->
        ParkBench.Timeline.StatusUpdate
        |> where([s], s.id == ^content_id)
        |> Repo.update_all(set: [ai_detection_status: status])

      "profile_photo" ->
        ParkBench.Accounts.ProfilePhoto
        |> where([p], p.id == ^content_id)
        |> Repo.update_all(set: [ai_detection_status: status])

      "photo" ->
        ParkBench.Media.Photo
        |> where([p], p.id == ^content_id)
        |> Repo.update_all(set: [ai_detection_status: status])

      "message" ->
        ParkBench.Messaging.Message
        |> where([m], m.id == ^content_id)
        |> Repo.update_all(set: [ai_detection_status: status])

      _ ->
        :ok
    end
  end

  # === Appeals ===

  def create_appeal(result_id, user_id, attrs) do
    result = get_result!(result_id)

    if result.user_id != user_id do
      {:error, :unauthorized}
    else
      %DetectionAppeal{}
      |> DetectionAppeal.changeset(
        Map.merge(attrs, %{
          detection_result_id: result_id,
          user_id: user_id
        })
      )
      |> Repo.insert()
      |> case do
        {:ok, appeal} ->
          # Update result status to appealed
          result
          |> DetectionResult.changeset(%{status: "appealed"})
          |> Repo.update()

          {:ok, appeal}

        error ->
          error
      end
    end
  end

  def list_pending_appeals(opts \\ []) do
    page = Keyword.get(opts, :page, 1)
    per_page = Keyword.get(opts, :per_page, 20)

    DetectionAppeal
    |> where([a], a.status == "pending")
    |> order_by([a], asc: a.inserted_at)
    |> offset(^((page - 1) * per_page))
    |> limit(^per_page)
    |> preload([:user, :detection_result])
    |> Repo.all()
  end

  def review_appeal(appeal_id, reviewer_id, decision) when decision in ["approved", "denied"] do
    appeal = Repo.get!(DetectionAppeal, appeal_id)
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Repo.transaction(fn ->
      # Update appeal
      appeal
      |> DetectionAppeal.review_changeset(%{
        status: decision,
        reviewed_by_id: reviewer_id,
        reviewed_at: now
      })
      |> Repo.update!()

      # If approved, update the content status
      if decision == "approved" do
        result = get_result!(appeal.detection_result_id)
        update_content_status(result.content_type, result.content_id, "approved")

        # Check for leniency boost (3+ approved appeals in 30 days)
        maybe_grant_leniency_boost(appeal.user_id)
      end
    end)
  end

  defp maybe_grant_leniency_boost(user_id) do
    thirty_days_ago = DateTime.add(DateTime.utc_now(), -30 * 86400, :second)

    approved_count =
      DetectionAppeal
      |> where([a], a.user_id == ^user_id and a.status == "approved")
      |> where([a], a.reviewed_at > ^thirty_days_ago)
      |> Repo.aggregate(:count)

    if approved_count >= 3 do
      user = ParkBench.Accounts.get_user!(user_id)
      # Cap at 0.15
      new_boost = min(user.ai_leniency_boost + 0.05, 0.15)

      user
      |> Ecto.Changeset.change(ai_leniency_boost: new_boost)
      |> Repo.update()
    end
  end

  # === Flagging ===

  def check_and_flag_user(user_id) do
    twenty_four_hours_ago = DateTime.add(DateTime.utc_now(), -86400, :second)

    rejection_count =
      DetectionResult
      |> where([r], r.user_id == ^user_id)
      |> where([r], r.status in ["soft_rejected", "hard_rejected"])
      |> where([r], r.inserted_at > ^twenty_four_hours_ago)
      |> Repo.aggregate(:count)

    if rejection_count >= 5 do
      user = ParkBench.Accounts.get_user!(user_id)
      user |> Ecto.Changeset.change(ai_flagged: true) |> Repo.update()
    end
  end

  # === Admin Stats ===

  def public_stats do
    stats = detection_stats()

    human_pct =
      if stats.total > 0, do: Float.round(stats.approved / stats.total * 100, 1), else: 100.0

    Map.merge(stats, %{human_percentage: human_pct})
  end

  def detection_stats do
    %{
      total: Repo.aggregate(DetectionResult, :count),
      pending: Repo.aggregate(from(r in DetectionResult, where: r.status == "pending"), :count),
      approved: Repo.aggregate(from(r in DetectionResult, where: r.status == "approved"), :count),
      rejected:
        Repo.aggregate(
          from(r in DetectionResult, where: r.status in ["soft_rejected", "hard_rejected"]),
          :count
        ),
      appeals_pending:
        Repo.aggregate(from(a in DetectionAppeal, where: a.status == "pending"), :count)
    }
  end
end
