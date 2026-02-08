defmodule ParkBench.AIDetectionTest do
  use ParkBench.DataCase, async: true
  use Oban.Testing, repo: ParkBench.Repo

  alias ParkBench.AIDetection
  alias ParkBench.AIDetection.{DetectionResult, DetectionAppeal, ThresholdServer}

  # Start the ThresholdServer for tests that need it
  setup do
    # If ThresholdServer is already running, we use it. Otherwise start it.
    case GenServer.whereis(ThresholdServer) do
      nil ->
        start_supervised!(ThresholdServer)

      _pid ->
        :ok
    end

    :ok
  end

  # ──────────────────────────────────────────────
  # check_text/4
  # ──────────────────────────────────────────────

  describe "check_text/4" do
    test "exempts short text (below minimum length)" do
      user = insert(:user)
      content_id = Ecto.UUID.generate()

      assert {:ok, result} =
               AIDetection.check_text(user.id, "wall_post", content_id, "Short")

      assert result.provider == "exempt"
      assert result.status == "approved"
      assert result.score == 0.0
    end

    test "uses cache when identical content was recently approved" do
      user = insert(:user)
      content_id1 = Ecto.UUID.generate()
      content_id2 = Ecto.UUID.generate()

      long_text = String.duplicate("This is a long enough text for detection. ", 5)

      # First check creates a result
      {:ok, first_result} = AIDetection.check_text(user.id, "wall_post", content_id1, long_text)

      # Manually approve the first result so the cache can find it
      first_result
      |> DetectionResult.changeset(%{status: "approved"})
      |> Repo.update!()

      # Second check with same text should get a cache hit
      {:ok, cached_result} = AIDetection.check_text(user.id, "wall_post", content_id2, long_text)
      assert cached_result.provider == "cache"
      assert cached_result.status == "approved"
    end

    test "enqueues Oban worker for new text detection" do
      user = insert(:user)
      content_id = Ecto.UUID.generate()

      long_text = String.duplicate("This is original content that needs checking. ", 5)

      {:ok, result} = AIDetection.check_text(user.id, "wall_post", content_id, long_text)
      assert result.status == "pending"
      assert result.provider == "gptzero"

      assert_enqueued(worker: ParkBench.Workers.AITextDetectionWorker)
    end
  end

  # ──────────────────────────────────────────────
  # check_image/4
  # ──────────────────────────────────────────────

  describe "check_image/4" do
    test "uses cache when identical image URL was recently approved" do
      user = insert(:user)
      content_id1 = Ecto.UUID.generate()
      content_id2 = Ecto.UUID.generate()
      image_url = "https://example.com/photo.jpg"

      # Create an approved result with matching hash
      content_hash = :crypto.hash(:sha256, image_url) |> Base.encode16(case: :lower)

      insert(:detection_result,
        user: user,
        content_type: "profile_photo",
        content_id: content_id1,
        provider: "hive",
        status: "approved",
        content_hash: content_hash
      )

      {:ok, cached} = AIDetection.check_image(user.id, "profile_photo", content_id2, image_url)
      assert cached.provider == "cache"
      assert cached.status == "approved"
    end

    test "enqueues Oban worker for new image detection" do
      user = insert(:user)
      content_id = Ecto.UUID.generate()
      image_url = "https://example.com/unique-photo-#{System.unique_integer()}.jpg"

      {:ok, result} = AIDetection.check_image(user.id, "profile_photo", content_id, image_url)
      assert result.status == "pending"
      assert result.provider == "hive"

      assert_enqueued(worker: ParkBench.Workers.AIImageDetectionWorker)
    end
  end

  # ──────────────────────────────────────────────
  # Results
  # ──────────────────────────────────────────────

  describe "create_result/1" do
    test "creates a detection result" do
      user = insert(:user)
      content_id = Ecto.UUID.generate()

      assert {:ok, result} =
               AIDetection.create_result(%{
                 user_id: user.id,
                 content_type: "wall_post",
                 content_id: content_id,
                 provider: "gptzero",
                 score: 0.42,
                 status: "pending",
                 content_hash: "abc123",
                 raw_response: %{"some" => "data"}
               })

      assert result.score == 0.42
      assert result.provider == "gptzero"
    end
  end

  describe "get_result/2" do
    test "returns the latest result for content" do
      user = insert(:user)
      content_id = Ecto.UUID.generate()

      {:ok, old} =
        AIDetection.create_result(%{
          user_id: user.id,
          content_type: "wall_post",
          content_id: content_id,
          provider: "gptzero",
          score: 0.1,
          status: "approved",
          content_hash: "hash1"
        })

      # Ensure the "old" result has an earlier timestamp
      old_time = DateTime.add(DateTime.utc_now(), -60, :second) |> DateTime.truncate(:second)

      Repo.get!(DetectionResult, old.id)
      |> Ecto.Changeset.change(inserted_at: old_time)
      |> Repo.update!()

      {:ok, newer} =
        AIDetection.create_result(%{
          user_id: user.id,
          content_type: "wall_post",
          content_id: content_id,
          provider: "gptzero",
          score: 0.8,
          status: "soft_rejected",
          content_hash: "hash2"
        })

      result = AIDetection.get_result("wall_post", content_id)
      assert result.id == newer.id
    end

    test "returns nil for non-existent content" do
      assert AIDetection.get_result("wall_post", Ecto.UUID.generate()) == nil
    end
  end

  describe "get_result!/1" do
    test "returns result by id" do
      result = insert(:detection_result)
      assert AIDetection.get_result!(result.id).id == result.id
    end

    test "raises for non-existent id" do
      assert_raise Ecto.NoResultsError, fn ->
        AIDetection.get_result!(Ecto.UUID.generate())
      end
    end
  end

  # ──────────────────────────────────────────────
  # determine_status/2
  # ──────────────────────────────────────────────

  describe "determine_status/2" do
    test "returns approved for low text score" do
      assert AIDetection.determine_status(0.3, :text) == "approved"
    end

    test "returns soft_rejected for medium text score" do
      assert AIDetection.determine_status(0.7, :text) == "soft_rejected"
    end

    test "returns hard_rejected for high text score" do
      assert AIDetection.determine_status(0.9, :text) == "hard_rejected"
    end

    test "returns approved for low image score" do
      assert AIDetection.determine_status(0.5, :image) == "approved"
    end

    test "returns soft_rejected for medium image score" do
      assert AIDetection.determine_status(0.75, :image) == "soft_rejected"
    end

    test "returns hard_rejected for high image score" do
      assert AIDetection.determine_status(0.95, :image) == "hard_rejected"
    end
  end

  # ──────────────────────────────────────────────
  # Thresholds
  # ──────────────────────────────────────────────

  describe "get_thresholds/0" do
    test "returns current thresholds" do
      thresholds = AIDetection.get_thresholds()
      assert is_map(thresholds)
      assert Map.has_key?(thresholds, :text_soft_reject)
      assert Map.has_key?(thresholds, :text_hard_reject)
      assert Map.has_key?(thresholds, :image_soft_reject)
      assert Map.has_key?(thresholds, :image_hard_reject)
    end
  end

  describe "update_thresholds/1" do
    test "updates threshold values" do
      {:ok, updated} =
        AIDetection.update_thresholds(%{
          text_soft_reject: 0.5,
          text_hard_reject: 0.8
        })

      assert updated.text_soft_reject == 0.5
      assert updated.text_hard_reject == 0.8

      # Verify the change persists
      current = AIDetection.get_thresholds()
      assert current.text_soft_reject == 0.5
    end
  end

  # ──────────────────────────────────────────────
  # update_content_status/3
  # ──────────────────────────────────────────────

  describe "update_content_status/3" do
    test "updates wall_post ai_detection_status" do
      user = insert(:user)

      {:ok, post} =
        ParkBench.Timeline.create_wall_post(%{
          author_id: user.id,
          wall_owner_id: user.id,
          body: "AI check post"
        })

      AIDetection.update_content_status("wall_post", post.id, "approved")

      updated = Repo.get!(ParkBench.Timeline.WallPost, post.id)
      assert updated.ai_detection_status == "approved"
    end

    test "updates comment ai_detection_status" do
      user = insert(:user)

      {:ok, post} =
        ParkBench.Timeline.create_wall_post(%{
          author_id: user.id,
          wall_owner_id: user.id,
          body: "Post for comment"
        })

      {:ok, comment} =
        ParkBench.Timeline.create_comment(%{
          author_id: user.id,
          commentable_type: "WallPost",
          commentable_id: post.id,
          body: "AI check comment"
        })

      AIDetection.update_content_status("comment", comment.id, "approved")

      updated = Repo.get!(ParkBench.Timeline.Comment, comment.id)
      assert updated.ai_detection_status == "approved"
    end

    test "updates status_update ai_detection_status" do
      user = insert(:user)

      {:ok, status} =
        ParkBench.Timeline.create_status_update(%{
          user_id: user.id,
          body: "AI check status"
        })

      AIDetection.update_content_status("status_update", status.id, "flagged")

      updated = Repo.get!(ParkBench.Timeline.StatusUpdate, status.id)
      assert updated.ai_detection_status == "flagged"
    end

    test "updates profile_photo ai_detection_status" do
      user = insert(:user)
      photo = insert(:profile_photo, user: user)

      AIDetection.update_content_status("profile_photo", photo.id, "clean")

      updated = Repo.get!(ParkBench.Accounts.ProfilePhoto, photo.id)
      assert updated.ai_detection_status == "clean"
    end

    test "handles unknown content type gracefully" do
      assert :ok = AIDetection.update_content_status("unknown", Ecto.UUID.generate(), "approved")
    end
  end

  # ──────────────────────────────────────────────
  # Appeals
  # ──────────────────────────────────────────────

  describe "create_appeal/3" do
    test "creates an appeal for the result owner" do
      user = insert(:user)
      result = insert(:detection_result, user: user, status: "soft_rejected")

      assert {:ok, appeal} =
               AIDetection.create_appeal(result.id, user.id, %{
                 explanation: "I wrote this by hand",
                 tools_used: "notepad"
               })

      assert appeal.explanation == "I wrote this by hand"
      assert appeal.status == "pending"

      # Result should be updated to "appealed"
      updated_result = Repo.get!(DetectionResult, result.id)
      assert updated_result.status == "appealed"
    end

    test "returns error when user is not the result owner" do
      user = insert(:user)
      other = insert(:user)
      result = insert(:detection_result, user: user, status: "soft_rejected")

      assert {:error, :unauthorized} =
               AIDetection.create_appeal(result.id, other.id, %{
                 explanation: "Not my content"
               })
    end
  end

  describe "list_pending_appeals/1" do
    test "returns pending appeals in order" do
      user = insert(:user)
      result = insert(:detection_result, user: user, status: "soft_rejected")

      insert(:detection_appeal,
        detection_result: result,
        user: user,
        status: "pending"
      )

      appeals = AIDetection.list_pending_appeals()
      assert length(appeals) >= 1
      assert hd(appeals).status == "pending"
    end

    test "paginates results" do
      user = insert(:user)

      for _ <- 1..5 do
        result = insert(:detection_result, user: user, status: "soft_rejected")

        insert(:detection_appeal,
          detection_result: result,
          user: user,
          status: "pending"
        )
      end

      page1 = AIDetection.list_pending_appeals(page: 1, per_page: 3)
      page2 = AIDetection.list_pending_appeals(page: 2, per_page: 3)

      assert length(page1) == 3
      assert length(page2) == 2
    end
  end

  describe "review_appeal/3" do
    test "approves an appeal and updates content status" do
      user = insert(:user)
      reviewer = insert(:user)

      {:ok, post} =
        ParkBench.Timeline.create_wall_post(%{
          author_id: user.id,
          wall_owner_id: user.id,
          body: "Appeal this post"
        })

      result =
        insert(:detection_result,
          user: user,
          content_type: "wall_post",
          content_id: post.id,
          status: "soft_rejected"
        )

      appeal =
        insert(:detection_appeal,
          detection_result: result,
          user: user,
          status: "pending"
        )

      assert {:ok, _} = AIDetection.review_appeal(appeal.id, reviewer.id, "approved")

      # Appeal should be updated
      updated_appeal = Repo.get!(DetectionAppeal, appeal.id)
      assert updated_appeal.status == "approved"
      assert updated_appeal.reviewed_by_id == reviewer.id
      assert updated_appeal.reviewed_at != nil

      # Content should be approved
      updated_post = Repo.get!(ParkBench.Timeline.WallPost, post.id)
      assert updated_post.ai_detection_status == "approved"
    end

    test "denies an appeal" do
      user = insert(:user)
      reviewer = insert(:user)
      result = insert(:detection_result, user: user, status: "soft_rejected")

      appeal =
        insert(:detection_appeal,
          detection_result: result,
          user: user,
          status: "pending"
        )

      assert {:ok, _} = AIDetection.review_appeal(appeal.id, reviewer.id, "denied")

      updated_appeal = Repo.get!(DetectionAppeal, appeal.id)
      assert updated_appeal.status == "denied"
    end

    test "grants leniency boost after 3+ approved appeals in 30 days" do
      user = insert(:user)
      reviewer = insert(:user)

      # Create 2 previously approved appeals within 30 days
      for _ <- 1..2 do
        r = insert(:detection_result, user: user, status: "soft_rejected")

        insert(:detection_appeal,
          detection_result: r,
          user: user,
          status: "approved",
          reviewed_by: reviewer,
          reviewed_at: DateTime.utc_now() |> DateTime.truncate(:second)
        )
      end

      # Create 3rd appeal to trigger leniency boost
      {:ok, post} =
        ParkBench.Timeline.create_wall_post(%{
          author_id: user.id,
          wall_owner_id: user.id,
          body: "Third appeal post"
        })

      result3 =
        insert(:detection_result,
          user: user,
          content_type: "wall_post",
          content_id: post.id,
          status: "soft_rejected"
        )

      appeal3 =
        insert(:detection_appeal,
          detection_result: result3,
          user: user,
          status: "pending"
        )

      {:ok, _} = AIDetection.review_appeal(appeal3.id, reviewer.id, "approved")

      updated_user = ParkBench.Accounts.get_user!(user.id)
      assert updated_user.ai_leniency_boost > 0.0
    end
  end

  # ──────────────────────────────────────────────
  # check_and_flag_user/1
  # ──────────────────────────────────────────────

  describe "check_and_flag_user/1" do
    test "does not flag user under threshold" do
      user = insert(:user)

      for _ <- 1..3 do
        insert(:detection_result, user: user, status: "soft_rejected")
      end

      AIDetection.check_and_flag_user(user.id)
      updated = ParkBench.Accounts.get_user!(user.id)
      refute updated.ai_flagged
    end

    test "flags user at or above threshold (5+ rejections in 24h)" do
      user = insert(:user)

      for _ <- 1..5 do
        insert(:detection_result, user: user, status: "soft_rejected")
      end

      AIDetection.check_and_flag_user(user.id)
      updated = ParkBench.Accounts.get_user!(user.id)
      assert updated.ai_flagged
    end
  end

  # ──────────────────────────────────────────────
  # detection_stats/0
  # ──────────────────────────────────────────────

  describe "detection_stats/0" do
    test "returns aggregate stats" do
      user = insert(:user)

      insert(:detection_result, user: user, status: "pending")
      insert(:detection_result, user: user, status: "approved")
      insert(:detection_result, user: user, status: "soft_rejected")
      insert(:detection_result, user: user, status: "hard_rejected")

      appeal_result = insert(:detection_result, user: user, status: "soft_rejected")

      insert(:detection_appeal,
        detection_result: appeal_result,
        user: user,
        status: "pending"
      )

      stats = AIDetection.detection_stats()

      assert stats.total >= 5
      assert stats.pending >= 1
      assert stats.approved >= 1
      assert stats.rejected >= 2
      assert stats.appeals_pending >= 1
    end
  end
end
