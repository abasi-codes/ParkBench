defmodule Sunporch.PrivacyTest do
  use Sunporch.DataCase, async: true

  alias Sunporch.Privacy

  defp make_friends(user1, user2) do
    {low, high} =
      if user1.id < user2.id, do: {user1, user2}, else: {user2, user1}

    insert(:friendship, user: low, friend: high)
  end

  # ──────────────────────────────────────────────
  # get_privacy_settings/1
  # ──────────────────────────────────────────────

  describe "get_privacy_settings/1" do
    test "creates default settings when none exist" do
      user = insert(:user)
      settings = Privacy.get_privacy_settings(user.id)

      assert settings.user_id == user.id
      assert settings.profile_visibility == "everyone"
      assert settings.bio_visibility == "friends"
      assert settings.phone_visibility == "only_me"
      assert settings.wall_posting == "friends"
    end

    test "returns existing settings on subsequent calls" do
      user = insert(:user)
      s1 = Privacy.get_privacy_settings(user.id)
      s2 = Privacy.get_privacy_settings(user.id)
      assert s1.id == s2.id
    end
  end

  # ──────────────────────────────────────────────
  # update_privacy_settings/2
  # ──────────────────────────────────────────────

  describe "update_privacy_settings/2" do
    test "updates privacy settings" do
      user = insert(:user)
      Privacy.get_privacy_settings(user.id)

      assert {:ok, updated} =
               Privacy.update_privacy_settings(user.id, %{
                 profile_visibility: "friends",
                 bio_visibility: "only_me",
                 wall_posting: "everyone"
               })

      assert updated.profile_visibility == "friends"
      assert updated.bio_visibility == "only_me"
      assert updated.wall_posting == "everyone"
    end

    test "creates settings if none exist before updating" do
      user = insert(:user)

      assert {:ok, updated} =
               Privacy.update_privacy_settings(user.id, %{
                 profile_visibility: "only_me"
               })

      assert updated.profile_visibility == "only_me"
    end
  end

  # ──────────────────────────────────────────────
  # visible_to?/3
  # ──────────────────────────────────────────────

  describe "visible_to?/3" do
    test "always visible to self regardless of setting" do
      user_id = Ecto.UUID.generate()
      assert Privacy.visible_to?("only_me", user_id, user_id)
      assert Privacy.visible_to?("friends", user_id, user_id)
      assert Privacy.visible_to?("everyone", user_id, user_id)
    end

    test "everyone is visible to all users" do
      viewer_id = Ecto.UUID.generate()
      owner_id = Ecto.UUID.generate()
      assert Privacy.visible_to?("everyone", viewer_id, owner_id)
    end

    test "only_me is not visible to others" do
      viewer_id = Ecto.UUID.generate()
      owner_id = Ecto.UUID.generate()
      refute Privacy.visible_to?("only_me", viewer_id, owner_id)
    end

    test "friends visibility with friendship" do
      user1 = insert(:user)
      user2 = insert(:user)
      make_friends(user1, user2)

      assert Privacy.visible_to?("friends", user1.id, user2.id)
    end

    test "friends visibility without friendship" do
      user1 = insert(:user)
      user2 = insert(:user)

      refute Privacy.visible_to?("friends", user1.id, user2.id)
    end

    test "unknown visibility defaults to false" do
      viewer_id = Ecto.UUID.generate()
      owner_id = Ecto.UUID.generate()
      refute Privacy.visible_to?("invalid_setting", viewer_id, owner_id)
    end
  end

  # ──────────────────────────────────────────────
  # can_view_profile?/2
  # ──────────────────────────────────────────────

  describe "can_view_profile?/2" do
    test "self can always view" do
      user = insert(:user)
      assert Privacy.can_view_profile?(user.id, user.id)
    end

    test "everyone can view when profile_visibility is 'everyone'" do
      owner = insert(:user)
      viewer = insert(:user)
      # Default is "everyone"
      assert Privacy.can_view_profile?(viewer.id, owner.id)
    end

    test "only friends can view when profile_visibility is 'friends'" do
      owner = insert(:user)
      friend = insert(:user)
      stranger = insert(:user)

      Privacy.update_privacy_settings(owner.id, %{profile_visibility: "friends"})
      make_friends(owner, friend)

      assert Privacy.can_view_profile?(friend.id, owner.id)
      refute Privacy.can_view_profile?(stranger.id, owner.id)
    end

    test "only self can view when profile_visibility is 'only_me'" do
      owner = insert(:user)
      viewer = insert(:user)

      Privacy.update_privacy_settings(owner.id, %{profile_visibility: "only_me"})
      refute Privacy.can_view_profile?(viewer.id, owner.id)
      assert Privacy.can_view_profile?(owner.id, owner.id)
    end
  end

  # ──────────────────────────────────────────────
  # can_post_on_wall?/2
  # ──────────────────────────────────────────────

  describe "can_post_on_wall?/2" do
    test "self can always post on own wall" do
      user = insert(:user)
      assert Privacy.can_post_on_wall?(user.id, user.id)
    end

    test "friends can post when wall_posting is 'friends'" do
      owner = insert(:user)
      friend = insert(:user)
      make_friends(owner, friend)

      # Default wall_posting is "friends"
      assert Privacy.can_post_on_wall?(friend.id, owner.id)
    end

    test "non-friends cannot post when wall_posting is 'friends'" do
      owner = insert(:user)
      stranger = insert(:user)

      refute Privacy.can_post_on_wall?(stranger.id, owner.id)
    end

    test "anyone can post when wall_posting is 'everyone'" do
      owner = insert(:user)
      stranger = insert(:user)

      Privacy.update_privacy_settings(owner.id, %{wall_posting: "everyone"})
      assert Privacy.can_post_on_wall?(stranger.id, owner.id)
    end

    test "nobody else can post when wall_posting is 'only_me'" do
      owner = insert(:user)
      friend = insert(:user)
      make_friends(owner, friend)

      Privacy.update_privacy_settings(owner.id, %{wall_posting: "only_me"})
      refute Privacy.can_post_on_wall?(friend.id, owner.id)
      assert Privacy.can_post_on_wall?(owner.id, owner.id)
    end
  end

  # ──────────────────────────────────────────────
  # visibility_options/0
  # ──────────────────────────────────────────────

  describe "visibility_options/0" do
    test "returns the three visibility options" do
      assert Privacy.visibility_options() == ["everyone", "friends", "only_me"]
    end
  end
end
