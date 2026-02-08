defmodule Sunporch.AccountsTest do
  use Sunporch.DataCase, async: true

  alias Sunporch.Accounts

  # ──────────────────────────────────────────────
  # User Registration
  # ──────────────────────────────────────────────

  describe "register_user/1" do
    test "creates a user with valid attributes" do
      attrs = %{
        email: "newuser@example.com",
        display_name: "New User",
        password: "securepass1",
        password_confirmation: "securepass1"
      }

      assert {:ok, user} = Accounts.register_user(attrs)
      assert user.email == "newuser@example.com"
      assert user.display_name == "New User"
      assert user.hashed_password != nil
      assert user.slug != nil
      assert String.starts_with?(user.slug, "new-user-")
      assert user.role == "user"
      assert user.email_verified_at == nil
    end

    test "returns error for duplicate email" do
      attrs = %{
        email: "dupe@example.com",
        display_name: "First User",
        password: "securepass1",
        password_confirmation: "securepass1"
      }

      assert {:ok, _} = Accounts.register_user(attrs)

      dup_attrs = %{attrs | display_name: "Second User"}
      assert {:error, changeset} = Accounts.register_user(dup_attrs)
      assert "has already been taken" in errors_on(changeset).email
    end

    test "returns error for invalid email format" do
      attrs = %{
        email: "notanemail",
        display_name: "Bad Email",
        password: "securepass1",
        password_confirmation: "securepass1"
      }

      assert {:error, changeset} = Accounts.register_user(attrs)
      assert errors_on(changeset).email != []
    end

    test "returns error for password shorter than 8 characters" do
      attrs = %{
        email: "short@example.com",
        display_name: "Short Pass",
        password: "abc",
        password_confirmation: "abc"
      }

      assert {:error, changeset} = Accounts.register_user(attrs)
      assert errors_on(changeset).password != []
    end

    test "returns error when password confirmation does not match" do
      attrs = %{
        email: "mismatch@example.com",
        display_name: "Mismatch",
        password: "securepass1",
        password_confirmation: "differentpass"
      }

      assert {:error, changeset} = Accounts.register_user(attrs)
      assert errors_on(changeset).password_confirmation != []
    end

    test "normalizes email to lowercase" do
      attrs = %{
        email: "UPPERcase@Example.COM",
        display_name: "Upper Case",
        password: "securepass1",
        password_confirmation: "securepass1"
      }

      assert {:ok, user} = Accounts.register_user(attrs)
      assert user.email == "uppercase@example.com"
    end
  end

  # ──────────────────────────────────────────────
  # User Retrieval
  # ──────────────────────────────────────────────

  describe "get_user!/1" do
    test "returns user for valid id" do
      user = insert(:user)
      assert Accounts.get_user!(user.id).id == user.id
    end

    test "raises for non-existent id" do
      assert_raise Ecto.NoResultsError, fn ->
        Accounts.get_user!(Ecto.UUID.generate())
      end
    end
  end

  describe "get_user/1" do
    test "returns user for valid id" do
      user = insert(:user)
      assert Accounts.get_user(user.id).id == user.id
    end

    test "returns nil for non-existent id" do
      assert Accounts.get_user(Ecto.UUID.generate()) == nil
    end
  end

  describe "get_user_by_email/1" do
    test "returns user with matching email" do
      user = insert(:user, email: "found@example.com")
      assert Accounts.get_user_by_email("found@example.com").id == user.id
    end

    test "is case-insensitive" do
      user = insert(:user, email: "casetest@example.com")
      assert Accounts.get_user_by_email("CASETEST@EXAMPLE.COM").id == user.id
    end

    test "returns nil for unknown email" do
      assert Accounts.get_user_by_email("ghost@example.com") == nil
    end
  end

  describe "get_user_by_slug/1" do
    test "returns user with matching slug" do
      user = insert(:user)
      assert Accounts.get_user_by_slug(user.slug).id == user.id
    end

    test "returns nil for unknown slug" do
      assert Accounts.get_user_by_slug("non-existent-slug") == nil
    end
  end

  # ──────────────────────────────────────────────
  # Authentication
  # ──────────────────────────────────────────────

  describe "authenticate_user/2" do
    test "returns user with correct credentials" do
      {:ok, user} =
        Accounts.register_user(%{
          email: "auth@example.com",
          display_name: "Auth User",
          password: "correct_pw1",
          password_confirmation: "correct_pw1"
        })

      assert {:ok, authed} = Accounts.authenticate_user("auth@example.com", "correct_pw1")
      assert authed.id == user.id
    end

    test "returns error with wrong password" do
      {:ok, _} =
        Accounts.register_user(%{
          email: "wrong@example.com",
          display_name: "Wrong PW",
          password: "correct_pw1",
          password_confirmation: "correct_pw1"
        })

      assert {:error, :invalid_credentials} =
               Accounts.authenticate_user("wrong@example.com", "wrong_password")
    end

    test "returns error for non-existent user" do
      assert {:error, :invalid_credentials} =
               Accounts.authenticate_user("ghost@example.com", "any_password")
    end

    test "returns error for locked account" do
      {:ok, user} =
        Accounts.register_user(%{
          email: "locked@example.com",
          display_name: "Locked User",
          password: "correct_pw1",
          password_confirmation: "correct_pw1"
        })

      # Lock the account by setting locked_at and 5+ failed attempts
      user
      |> Ecto.Changeset.change(
        locked_at: DateTime.utc_now() |> DateTime.truncate(:second),
        failed_login_attempts: 5
      )
      |> Repo.update!()

      assert {:error, :account_locked} =
               Accounts.authenticate_user("locked@example.com", "correct_pw1")
    end

    test "increments failed_login_attempts on wrong password" do
      {:ok, user} =
        Accounts.register_user(%{
          email: "attempts@example.com",
          display_name: "Attempts User",
          password: "correct_pw1",
          password_confirmation: "correct_pw1"
        })

      assert {:error, :invalid_credentials} =
               Accounts.authenticate_user("attempts@example.com", "wrong")

      updated = Accounts.get_user!(user.id)
      assert updated.failed_login_attempts == 1
    end

    test "resets failed attempts on successful login" do
      {:ok, user} =
        Accounts.register_user(%{
          email: "reset@example.com",
          display_name: "Reset User",
          password: "correct_pw1",
          password_confirmation: "correct_pw1"
        })

      user
      |> Ecto.Changeset.change(failed_login_attempts: 3)
      |> Repo.update!()

      assert {:ok, _} = Accounts.authenticate_user("reset@example.com", "correct_pw1")
      updated = Accounts.get_user!(user.id)
      assert updated.failed_login_attempts == 0
    end
  end

  # ──────────────────────────────────────────────
  # Sessions
  # ──────────────────────────────────────────────

  describe "create_session/1" do
    test "creates a session and returns raw token" do
      user = insert(:user)
      assert {:ok, raw_token, session} = Accounts.create_session(user)

      assert is_binary(raw_token)
      assert session.user_id == user.id
      assert session.expires_at != nil
    end

    test "enforces maximum sessions" do
      user = insert(:user)

      # Create 5 sessions (the max)
      tokens =
        for _ <- 1..6 do
          {:ok, token, _session} = Accounts.create_session(user)
          token
        end

      # Should have at most 5 sessions
      session_count =
        Sunporch.Accounts.Session
        |> where([s], s.user_id == ^user.id)
        |> Repo.aggregate(:count)

      assert session_count <= 5

      # The latest token should still work
      last_token = List.last(tokens)
      assert Accounts.get_user_by_session_token(last_token) != nil
    end
  end

  describe "get_user_by_session_token/1" do
    test "returns user for valid token" do
      user = insert(:user)
      {:ok, raw_token, _session} = Accounts.create_session(user)

      assert found = Accounts.get_user_by_session_token(raw_token)
      assert found.id == user.id
    end

    test "returns nil for expired session" do
      user = insert(:user)
      {:ok, raw_token, session} = Accounts.create_session(user)

      # Manually expire the session
      session
      |> Ecto.Changeset.change(
        expires_at:
          DateTime.utc_now()
          |> DateTime.add(-3600, :second)
          |> DateTime.truncate(:second)
      )
      |> Repo.update!()

      assert Accounts.get_user_by_session_token(raw_token) == nil
    end

    test "returns nil for invalid token" do
      assert Accounts.get_user_by_session_token("invalid_base64_token") == nil
    end

    test "returns nil for completely bogus input" do
      assert Accounts.get_user_by_session_token(nil) == nil
    end
  end

  describe "delete_session/1" do
    test "deletes the session matching the token" do
      user = insert(:user)
      {:ok, raw_token, _session} = Accounts.create_session(user)

      assert :ok = Accounts.delete_session(raw_token)
      assert Accounts.get_user_by_session_token(raw_token) == nil
    end

    test "returns :ok for unknown token" do
      token = Base.encode64(:crypto.strong_rand_bytes(32))
      assert :ok = Accounts.delete_session(token)
    end
  end

  describe "delete_all_sessions/1" do
    test "deletes all sessions for a user" do
      user = insert(:user)
      {:ok, t1, _} = Accounts.create_session(user)
      {:ok, t2, _} = Accounts.create_session(user)

      Accounts.delete_all_sessions(user.id)

      assert Accounts.get_user_by_session_token(t1) == nil
      assert Accounts.get_user_by_session_token(t2) == nil
    end
  end

  # ──────────────────────────────────────────────
  # Email Verification
  # ──────────────────────────────────────────────

  describe "create_email_verification_token/1" do
    test "creates a token for the user" do
      user = insert(:user)
      assert {:ok, token} = Accounts.create_email_verification_token(user)
      assert is_binary(token)
      assert String.length(token) > 0
    end
  end

  describe "verify_email/1" do
    test "verifies the user email with a valid token" do
      user = insert(:user)
      {:ok, token} = Accounts.create_email_verification_token(user)

      assert {:ok, _result} = Accounts.verify_email(token)

      updated_user = Accounts.get_user!(user.id)
      assert updated_user.email_verified_at != nil
    end

    test "returns error for expired token" do
      user = insert(:user)

      # Insert a token that is already expired
      expired =
        insert(:email_verification_token,
          user: user,
          expires_at:
            DateTime.utc_now()
            |> DateTime.add(-3600, :second)
            |> DateTime.truncate(:second)
        )

      assert {:error, :invalid_token} = Accounts.verify_email(expired.token)
    end

    test "returns error for already used token" do
      user = insert(:user)

      used =
        insert(:email_verification_token,
          user: user,
          used_at: DateTime.utc_now() |> DateTime.truncate(:second)
        )

      assert {:error, :invalid_token} = Accounts.verify_email(used.token)
    end

    test "returns error for non-existent token" do
      assert {:error, :invalid_token} = Accounts.verify_email("bogus_token")
    end
  end

  # ──────────────────────────────────────────────
  # Password Reset
  # ──────────────────────────────────────────────

  describe "create_password_reset_token/1" do
    test "creates a token for existing user" do
      user = insert(:user, email: "resetme@example.com")
      assert {:ok, token} = Accounts.create_password_reset_token("resetme@example.com")
      assert is_binary(token)
    end

    test "returns :noop for unknown email (no leak)" do
      assert {:ok, :noop} = Accounts.create_password_reset_token("unknown@example.com")
    end
  end

  describe "reset_password/3" do
    test "resets password with valid token" do
      {:ok, user} =
        Accounts.register_user(%{
          email: "pwreset@example.com",
          display_name: "PW Reset",
          password: "old_password1",
          password_confirmation: "old_password1"
        })

      {:ok, token} = Accounts.create_password_reset_token("pwreset@example.com")

      assert {:ok, _} = Accounts.reset_password(token, "new_password1", "new_password1")

      # Old password should no longer work
      assert {:error, :invalid_credentials} =
               Accounts.authenticate_user("pwreset@example.com", "old_password1")

      # New password should work
      assert {:ok, _} = Accounts.authenticate_user("pwreset@example.com", "new_password1")
    end

    test "invalidates all sessions after password reset" do
      {:ok, user} =
        Accounts.register_user(%{
          email: "pwinval@example.com",
          display_name: "PW Invalidate",
          password: "old_password1",
          password_confirmation: "old_password1"
        })

      {:ok, session_token, _} = Accounts.create_session(user)
      {:ok, token} = Accounts.create_password_reset_token("pwinval@example.com")
      {:ok, _} = Accounts.reset_password(token, "new_password1", "new_password1")

      assert Accounts.get_user_by_session_token(session_token) == nil
    end

    test "returns error for expired reset token" do
      user = insert(:user, email: "expired_reset@example.com")

      expired =
        insert(:password_reset_token,
          user: user,
          expires_at:
            DateTime.utc_now()
            |> DateTime.add(-7200, :second)
            |> DateTime.truncate(:second)
        )

      assert {:error, :invalid_token} =
               Accounts.reset_password(expired.token, "new_pass123", "new_pass123")
    end

    test "returns error for already used reset token" do
      user = insert(:user)

      used =
        insert(:password_reset_token,
          user: user,
          used_at: DateTime.utc_now() |> DateTime.truncate(:second)
        )

      assert {:error, :invalid_token} =
               Accounts.reset_password(used.token, "new_pass123", "new_pass123")
    end
  end

  # ──────────────────────────────────────────────
  # Profiles
  # ──────────────────────────────────────────────

  describe "get_or_create_profile/1" do
    test "creates a profile when none exists" do
      user = insert(:user)
      assert {:ok, profile} = Accounts.get_or_create_profile(user.id)
      assert profile.user_id == user.id
    end

    test "returns existing profile on second call" do
      user = insert(:user)
      {:ok, p1} = Accounts.get_or_create_profile(user.id)
      {:ok, p2} = Accounts.get_or_create_profile(user.id)
      assert p1.user_id == p2.user_id
    end
  end

  describe "update_profile/2" do
    test "updates the user profile" do
      user = insert(:user)
      {:ok, _} = Accounts.get_or_create_profile(user.id)

      assert {:ok, profile} =
               Accounts.update_profile(user.id, %{bio: "Updated bio", hometown: "New Town"})

      assert profile.bio == "Updated bio"
      assert profile.hometown == "New Town"
    end

    test "creates profile if it does not exist before updating" do
      user = insert(:user)

      assert {:ok, profile} = Accounts.update_profile(user.id, %{bio: "New bio"})
      assert profile.bio == "New bio"
    end
  end

  # ──────────────────────────────────────────────
  # Profile Photos
  # ──────────────────────────────────────────────

  describe "create_profile_photo/2" do
    test "creates a new current profile photo" do
      user = insert(:user)

      assert {:ok, photo} =
               Accounts.create_profile_photo(user.id, %{
                 original_url: "https://example.com/photo.jpg"
               })

      assert photo.is_current == true
      assert photo.user_id == user.id
    end

    test "sets previous photos to not current" do
      user = insert(:user)

      {:ok, first} =
        Accounts.create_profile_photo(user.id, %{
          original_url: "https://example.com/first.jpg"
        })

      {:ok, second} =
        Accounts.create_profile_photo(user.id, %{
          original_url: "https://example.com/second.jpg"
        })

      # Reload first photo
      reloaded_first = Repo.get!(Sunporch.Accounts.ProfilePhoto, first.id)
      assert reloaded_first.is_current == false
      assert second.is_current == true
    end
  end

  describe "create_profile_photo/2 feed item" do
    test "creates a profile_photo_updated feed item" do
      user = insert(:user)

      {:ok, photo} =
        Accounts.create_profile_photo(user.id, %{
          original_url: "https://example.com/new-profile.jpg"
        })

      feed_items =
        Sunporch.Timeline.FeedItem
        |> where([fi], fi.user_id == ^user.id and fi.item_type == "profile_photo_updated")
        |> Repo.all()

      assert length(feed_items) == 1
      assert hd(feed_items).content_id == photo.id
    end
  end

  describe "update_cover_photo/2 feed item" do
    test "creates a profile_updated feed item" do
      user = insert(:user)

      {:ok, _profile} = Accounts.update_cover_photo(user.id, "https://example.com/cover.jpg")

      feed_items =
        Sunporch.Timeline.FeedItem
        |> where([fi], fi.user_id == ^user.id and fi.item_type == "profile_updated")
        |> Repo.all()

      assert length(feed_items) == 1
      assert hd(feed_items).content_id == user.id
    end
  end

  describe "get_current_profile_photo/1" do
    test "returns the current photo" do
      user = insert(:user)

      {:ok, _old} =
        Accounts.create_profile_photo(user.id, %{
          original_url: "https://example.com/old.jpg"
        })

      {:ok, current} =
        Accounts.create_profile_photo(user.id, %{
          original_url: "https://example.com/current.jpg"
        })

      photo = Accounts.get_current_profile_photo(user.id)
      assert photo.id == current.id
    end

    test "returns nil when no photos" do
      user = insert(:user)
      assert Accounts.get_current_profile_photo(user.id) == nil
    end
  end

  # ──────────────────────────────────────────────
  # Education Entries
  # ──────────────────────────────────────────────

  describe "list_education_entries/1" do
    test "returns entries ordered by end_year desc" do
      user = insert(:user)

      insert(:education_entry, user: user, school_name: "Old School", end_year: 2010)
      insert(:education_entry, user: user, school_name: "New School", end_year: 2020)

      entries = Accounts.list_education_entries(user.id)
      assert length(entries) == 2
      assert hd(entries).school_name == "New School"
    end
  end

  describe "create_education_entry/2" do
    test "creates an education entry" do
      user = insert(:user)

      assert {:ok, entry} =
               Accounts.create_education_entry(user.id, %{
                 "school_name" => "MIT",
                 "degree" => "MS",
                 "start_year" => 2015,
                 "end_year" => 2017
               })

      assert entry.school_name == "MIT"
      assert entry.user_id == user.id
    end
  end

  describe "update_education_entry/2" do
    test "updates an education entry" do
      entry = insert(:education_entry)

      assert {:ok, updated} =
               Accounts.update_education_entry(entry.id, %{"school_name" => "Updated University"})

      assert updated.school_name == "Updated University"
    end
  end

  describe "delete_education_entry/1" do
    test "deletes an education entry" do
      entry = insert(:education_entry)
      assert {:ok, _} = Accounts.delete_education_entry(entry.id)

      assert_raise Ecto.NoResultsError, fn ->
        Repo.get!(Sunporch.Accounts.EducationEntry, entry.id)
      end
    end
  end

  # ──────────────────────────────────────────────
  # Work Entries
  # ──────────────────────────────────────────────

  describe "list_work_entries/1" do
    test "returns entries ordered by current first, then start_date desc" do
      user = insert(:user)

      insert(:work_entry,
        user: user,
        company_name: "Old Co",
        start_date: ~D[2010-01-01],
        end_date: ~D[2015-01-01],
        is_current: false
      )

      insert(:work_entry,
        user: user,
        company_name: "Current Co",
        start_date: ~D[2020-01-01],
        end_date: nil,
        is_current: true
      )

      entries = Accounts.list_work_entries(user.id)
      assert length(entries) == 2
      assert hd(entries).company_name == "Current Co"
    end
  end

  describe "create_work_entry/2" do
    test "creates a work entry" do
      user = insert(:user)

      assert {:ok, entry} =
               Accounts.create_work_entry(user.id, %{
                 "company_name" => "Acme Inc",
                 "position" => "Engineer",
                 "start_date" => "2020-01-01"
               })

      assert entry.company_name == "Acme Inc"
      assert entry.user_id == user.id
    end
  end

  describe "update_work_entry/2" do
    test "updates a work entry" do
      entry = insert(:work_entry)

      assert {:ok, updated} =
               Accounts.update_work_entry(entry.id, %{"company_name" => "Updated Company"})

      assert updated.company_name == "Updated Company"
    end
  end

  describe "delete_work_entry/1" do
    test "deletes a work entry" do
      entry = insert(:work_entry)
      assert {:ok, _} = Accounts.delete_work_entry(entry.id)

      assert_raise Ecto.NoResultsError, fn ->
        Repo.get!(Sunporch.Accounts.WorkEntry, entry.id)
      end
    end
  end

  # ──────────────────────────────────────────────
  # User Search
  # ──────────────────────────────────────────────

  describe "search_users/2" do
    test "finds users by display name substring" do
      insert(:user,
        display_name: "Alice Wonderland",
        email_verified_at: DateTime.utc_now() |> DateTime.truncate(:second)
      )

      insert(:user,
        display_name: "Bob Builder",
        email_verified_at: DateTime.utc_now() |> DateTime.truncate(:second)
      )

      results = Accounts.search_users("alice")
      assert length(results) == 1
      assert hd(results).display_name == "Alice Wonderland"
    end

    test "excludes current user" do
      me =
        insert(:user,
          display_name: "Me Myself",
          email_verified_at: DateTime.utc_now() |> DateTime.truncate(:second)
        )

      results = Accounts.search_users("Me Myself", current_user_id: me.id)
      assert results == []
    end

    test "only finds verified users" do
      insert(:user, display_name: "Unverified User", email_verified_at: nil)
      results = Accounts.search_users("Unverified")
      assert results == []
    end
  end

  describe "search_users_autocomplete/2" do
    test "returns matching users with prefix matching" do
      user =
        insert(:user,
          display_name: "Alice Wonderland",
          email_verified_at: DateTime.utc_now() |> DateTime.truncate(:second)
        )

      me = insert(:user)

      results = Accounts.search_users_autocomplete("Alice", me.id)
      assert length(results) == 1
      assert hd(results).display_name == "Alice Wonderland"
    end

    test "returns at most 5 results" do
      me = insert(:user)

      for i <- 1..7 do
        insert(:user,
          display_name: "Searchable User #{i}",
          email_verified_at: DateTime.utc_now() |> DateTime.truncate(:second)
        )
      end

      results = Accounts.search_users_autocomplete("Searchable", me.id)
      assert length(results) <= 5
    end
  end

  # ──────────────────────────────────────────────
  # Privacy Helper
  # ──────────────────────────────────────────────

  describe "visible_to?/3" do
    test "always visible to self" do
      user_id = Ecto.UUID.generate()
      assert Accounts.visible_to?("only_me", user_id, user_id)
      assert Accounts.visible_to?("friends", user_id, user_id)
      assert Accounts.visible_to?("everyone", user_id, user_id)
    end

    test "everyone visibility is visible to anyone" do
      viewer = Ecto.UUID.generate()
      owner = Ecto.UUID.generate()
      assert Accounts.visible_to?("everyone", viewer, owner)
    end

    test "only_me is not visible to others" do
      viewer = Ecto.UUID.generate()
      owner = Ecto.UUID.generate()
      refute Accounts.visible_to?("only_me", viewer, owner)
    end

    test "friends visibility requires friendship" do
      user1 = insert(:user)
      user2 = insert(:user)

      # Not friends yet
      refute Accounts.visible_to?("friends", user1.id, user2.id)

      # Create friendship with canonical ordering
      {low, high} = if user1.id < user2.id, do: {user1.id, user2.id}, else: {user2.id, user1.id}
      insert(:friendship, user: Repo.get!(Sunporch.Accounts.User, low), friend: Repo.get!(Sunporch.Accounts.User, high))

      assert Accounts.visible_to?("friends", user1.id, user2.id)
    end
  end
end
