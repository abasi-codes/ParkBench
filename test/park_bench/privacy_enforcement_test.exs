defmodule ParkBench.PrivacyEnforcementTest do
  use ParkBench.DataCase, async: true

  alias ParkBench.{Timeline, Privacy, Social}

  defp make_friends(user1, user2) do
    {low, high} =
      if user1.id < user2.id, do: {user1, user2}, else: {user2, user1}

    insert(:friendship, user: low, friend: high)
  end

  describe "Timeline.can_post_on_wall?/2" do
    test "owner can always post on own wall" do
      user = insert(:user)
      assert Timeline.can_post_on_wall?(user.id, user.id)
    end

    test "friends can post when wall_posting is 'friends'" do
      user = insert(:user)
      friend = insert(:user)
      make_friends(user, friend)
      insert(:privacy_setting, user: user, wall_posting: "friends")

      assert Timeline.can_post_on_wall?(friend.id, user.id)
    end

    test "non-friends cannot post when wall_posting is 'friends'" do
      user = insert(:user)
      stranger = insert(:user)
      insert(:privacy_setting, user: user, wall_posting: "friends")

      refute Timeline.can_post_on_wall?(stranger.id, user.id)
    end

    test "nobody can post when wall_posting is 'only_me'" do
      user = insert(:user)
      friend = insert(:user)
      make_friends(user, friend)
      insert(:privacy_setting, user: user, wall_posting: "only_me")

      refute Timeline.can_post_on_wall?(friend.id, user.id)
    end

    test "everyone can post when wall_posting is 'everyone'" do
      user = insert(:user)
      stranger = insert(:user)
      insert(:privacy_setting, user: user, wall_posting: "everyone")

      assert Timeline.can_post_on_wall?(stranger.id, user.id)
    end

    test "blocked users cannot post regardless of settings" do
      user = insert(:user)
      blocked = insert(:user)
      make_friends(user, blocked)
      insert(:privacy_setting, user: user, wall_posting: "everyone")
      Social.block_user(user.id, blocked.id)

      refute Timeline.can_post_on_wall?(blocked.id, user.id)
    end
  end

  describe "Privacy.can_view_profile?/2" do
    test "returns true for 'everyone' profile visibility" do
      user = insert(:user)
      stranger = insert(:user)
      insert(:privacy_setting, user: user, profile_visibility: "everyone")

      assert Privacy.can_view_profile?(stranger.id, user.id)
    end

    test "returns false for 'only_me' profile visibility" do
      user = insert(:user)
      stranger = insert(:user)
      insert(:privacy_setting, user: user, profile_visibility: "only_me")

      refute Privacy.can_view_profile?(stranger.id, user.id)
    end

    test "returns true for 'friends' when viewer is a friend" do
      user = insert(:user)
      friend = insert(:user)
      make_friends(user, friend)
      insert(:privacy_setting, user: user, profile_visibility: "friends")

      assert Privacy.can_view_profile?(friend.id, user.id)
    end

    test "returns false for 'friends' when viewer is not a friend" do
      user = insert(:user)
      stranger = insert(:user)
      insert(:privacy_setting, user: user, profile_visibility: "friends")

      refute Privacy.can_view_profile?(stranger.id, user.id)
    end

    test "owner can always view their own profile" do
      user = insert(:user)
      insert(:privacy_setting, user: user, profile_visibility: "only_me")

      assert Privacy.can_view_profile?(user.id, user.id)
    end
  end

  describe "friend list visibility" do
    test "visible_to? respects friend_list_visibility setting" do
      user = insert(:user)
      stranger = insert(:user)
      settings = insert(:privacy_setting, user: user, friend_list_visibility: "only_me")

      refute Privacy.visible_to?(settings.friend_list_visibility, stranger.id, user.id)
    end

    test "owner can always see own friend list" do
      user = insert(:user)
      settings = insert(:privacy_setting, user: user, friend_list_visibility: "only_me")

      assert Privacy.visible_to?(settings.friend_list_visibility, user.id, user.id)
    end

    test "friends can see friend list when set to 'friends'" do
      user = insert(:user)
      friend = insert(:user)
      make_friends(user, friend)
      settings = insert(:privacy_setting, user: user, friend_list_visibility: "friends")

      assert Privacy.visible_to?(settings.friend_list_visibility, friend.id, user.id)
    end
  end
end
