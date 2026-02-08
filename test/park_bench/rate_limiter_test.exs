defmodule ParkBench.RateLimiterTest do
  use ExUnit.Case, async: false

  alias ParkBench.RateLimiter

  setup do
    user_id = Ecto.UUID.generate()
    # Clean up before each test
    RateLimiter.reset(user_id, :test_action)
    {:ok, user_id: user_id}
  end

  describe "check/3" do
    test "allows requests under the limit", %{user_id: user_id} do
      assert :ok = RateLimiter.check(user_id, :test_action, limit: 5, window: 60_000)
      assert :ok = RateLimiter.check(user_id, :test_action, limit: 5, window: 60_000)
      assert :ok = RateLimiter.check(user_id, :test_action, limit: 5, window: 60_000)
    end

    test "blocks requests over the limit", %{user_id: user_id} do
      for _ <- 1..3 do
        assert :ok = RateLimiter.check(user_id, :test_action, limit: 3, window: 60_000)
      end

      assert {:error, :rate_limited} =
               RateLimiter.check(user_id, :test_action, limit: 3, window: 60_000)
    end

    test "different users have independent limits", %{user_id: user_id} do
      other_id = Ecto.UUID.generate()

      for _ <- 1..3 do
        RateLimiter.check(user_id, :test_action, limit: 3, window: 60_000)
      end

      # user_id is exhausted
      assert {:error, :rate_limited} =
               RateLimiter.check(user_id, :test_action, limit: 3, window: 60_000)

      # other_id still has capacity
      assert :ok = RateLimiter.check(other_id, :test_action, limit: 3, window: 60_000)
    end

    test "different actions have independent limits", %{user_id: user_id} do
      for _ <- 1..2 do
        RateLimiter.check(user_id, :action_a, limit: 2, window: 60_000)
      end

      assert {:error, :rate_limited} =
               RateLimiter.check(user_id, :action_a, limit: 2, window: 60_000)

      # Different action still works
      assert :ok = RateLimiter.check(user_id, :action_b, limit: 2, window: 60_000)
    end

    test "expired entries are cleaned up", %{user_id: user_id} do
      # Use a tiny window (1ms)
      for _ <- 1..3 do
        RateLimiter.check(user_id, :expiry_test, limit: 3, window: 1)
      end

      # Wait for the window to expire
      Process.sleep(5)

      # Should be allowed again
      assert :ok = RateLimiter.check(user_id, :expiry_test, limit: 3, window: 1)
    end

    test "uses default limits for known actions", %{user_id: user_id} do
      # create_wall_post has default limit: 10, window: 300_000
      assert :ok = RateLimiter.check(user_id, :create_wall_post)
    end
  end

  describe "reset/2" do
    test "clears rate limit entries", %{user_id: user_id} do
      for _ <- 1..3 do
        RateLimiter.check(user_id, :reset_test, limit: 3, window: 60_000)
      end

      assert {:error, :rate_limited} =
               RateLimiter.check(user_id, :reset_test, limit: 3, window: 60_000)

      RateLimiter.reset(user_id, :reset_test)

      assert :ok = RateLimiter.check(user_id, :reset_test, limit: 3, window: 60_000)
    end
  end
end
