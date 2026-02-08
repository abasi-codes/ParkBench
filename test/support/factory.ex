defmodule Sunporch.Factory do
  @moduledoc """
  ExMachina factories for all Sunporch schemas.
  """

  use ExMachina.Ecto, repo: Sunporch.Repo

  alias Sunporch.Accounts.{
    User,
    Session,
    EmailVerificationToken,
    PasswordResetToken,
    UserProfile,
    ProfilePhoto,
    EducationEntry,
    WorkEntry
  }

  alias Sunporch.Social.{Friendship, FriendRequest, Poke}

  alias Sunporch.Timeline.{WallPost, Comment, Like, StatusUpdate, FeedItem}

  alias Sunporch.Messaging.{MessageThread, MessageThreadParticipant, Message}

  alias Sunporch.Notifications.Notification

  alias Sunporch.Privacy.{PrivacySetting, Block}

  alias Sunporch.Media.{PhotoAlbum, Photo}

  alias Sunporch.AIDetection.{DetectionResult, DetectionAppeal}

  # ── Accounts ──────────────────────────────────────────────────────────

  def user_factory do
    display_name = sequence(:display_name, &"Test User #{&1}")
    slug = "#{display_name |> String.downcase() |> String.replace(~r/[^a-z0-9]+/, "-")}-#{:crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)}"

    %User{
      email: sequence(:email, &"user#{&1}@example.com"),
      display_name: display_name,
      hashed_password: Argon2.hash_pwd_salt("password123"),
      slug: slug,
      role: "user",
      email_verified_at: nil,
      locked_at: nil,
      failed_login_attempts: 0,
      last_failed_login_at: nil,
      ai_flagged: false,
      ai_leniency_boost: 0.0,
      onboarding_completed_at: nil
    }
  end

  def session_factory do
    %Session{
      token_hash: :crypto.strong_rand_bytes(32) |> Base.encode64(),
      ip_address: "127.0.0.1",
      user_agent: "ExUnit/1.0",
      last_active_at: DateTime.utc_now() |> DateTime.truncate(:second),
      expires_at: DateTime.utc_now() |> DateTime.add(86_400, :second) |> DateTime.truncate(:second),
      user: build(:user)
    }
  end

  def email_verification_token_factory do
    %EmailVerificationToken{
      token: :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false),
      expires_at: DateTime.utc_now() |> DateTime.add(86_400, :second) |> DateTime.truncate(:second),
      used_at: nil,
      user: build(:user)
    }
  end

  def password_reset_token_factory do
    %PasswordResetToken{
      token: :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false),
      expires_at: DateTime.utc_now() |> DateTime.add(86_400, :second) |> DateTime.truncate(:second),
      used_at: nil,
      user: build(:user)
    }
  end

  def user_profile_factory do
    %UserProfile{
      user: build(:user),
      bio: "A short bio about this person.",
      interests: "Reading, hiking, coding",
      hometown: "Springfield",
      current_city: "Shelbyville",
      birthday: ~D[1990-01-15],
      gender: "prefer not to say",
      relationship_status: "single",
      political_views: nil,
      religious_views: nil,
      website: "https://example.com",
      phone: "555-0100"
    }
  end

  def profile_photo_factory do
    %ProfilePhoto{
      original_url: sequence(:original_url, &"https://cdn.example.com/photos/original_#{&1}.jpg"),
      thumb_200_url: sequence(:thumb_200_url, &"https://cdn.example.com/photos/thumb200_#{&1}.jpg"),
      thumb_50_url: sequence(:thumb_50_url, &"https://cdn.example.com/photos/thumb50_#{&1}.jpg"),
      is_current: false,
      ai_detection_status: "pending",
      ai_detection_score: nil,
      content_hash: :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower),
      user: build(:user)
    }
  end

  def education_entry_factory do
    %EducationEntry{
      school_name: sequence(:school_name, &"University #{&1}"),
      degree: "Bachelor of Science",
      field_of_study: "Computer Science",
      description: "Studied computer science with a focus on distributed systems.",
      start_year: 2010,
      end_year: 2014,
      user: build(:user)
    }
  end

  def work_entry_factory do
    %WorkEntry{
      company_name: sequence(:company_name, &"Company #{&1}"),
      position: "Software Engineer",
      city: "San Francisco",
      description: "Worked on backend services.",
      start_date: ~D[2015-06-01],
      end_date: ~D[2020-12-31],
      is_current: false,
      user: build(:user)
    }
  end

  # ── Social ────────────────────────────────────────────────────────────

  def friendship_factory do
    user = build(:user)
    friend = build(:user)

    # Canonical ordering: user_id < friend_id.
    # Since these are built (not inserted), we generate UUIDs to guarantee
    # ordering at insert time. The caller can also override.
    {u, f} =
      case {Ecto.UUID.generate(), Ecto.UUID.generate()} do
        {id1, id2} when id1 < id2 -> {%{user | id: id1}, %{friend | id: id2}}
        {id1, id2} -> {%{user | id: id2}, %{friend | id: id1}}
      end

    %Friendship{
      user: u,
      friend: f
    }
  end

  def friend_request_factory do
    %FriendRequest{
      status: "pending",
      sender: build(:user),
      receiver: build(:user)
    }
  end

  def poke_factory do
    %Poke{
      poker: build(:user),
      pokee: build(:user)
    }
  end

  # ── Timeline ──────────────────────────────────────────────────────────

  def wall_post_factory do
    %WallPost{
      body: sequence(:wall_post_body, &"This is wall post number #{&1}."),
      ai_detection_status: "pending",
      ai_detection_score: nil,
      content_hash: :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower),
      deleted_at: nil,
      author: build(:user),
      wall_owner: build(:user)
    }
  end

  def comment_factory do
    %Comment{
      commentable_type: "wall_post",
      commentable_id: Ecto.UUID.generate(),
      body: sequence(:comment_body, &"This is comment number #{&1}."),
      ai_detection_status: "pending",
      ai_detection_score: nil,
      content_hash: :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower),
      deleted_at: nil,
      author: build(:user)
    }
  end

  def like_factory do
    %Like{
      likeable_type: "wall_post",
      likeable_id: Ecto.UUID.generate(),
      user: build(:user)
    }
  end

  def status_update_factory do
    %StatusUpdate{
      body: sequence(:status_update_body, &"Status update #{&1}."),
      ai_detection_status: "pending",
      ai_detection_score: nil,
      content_hash: :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower),
      user: build(:user)
    }
  end

  def feed_item_factory do
    %FeedItem{
      item_type: "wall_post",
      content_id: Ecto.UUID.generate(),
      user: build(:user)
    }
  end

  # ── Messaging ─────────────────────────────────────────────────────────

  def message_thread_factory do
    %MessageThread{
      subject: sequence(:thread_subject, &"Thread Subject #{&1}"),
      type: "inbox",
      last_message_at: DateTime.utc_now() |> DateTime.truncate(:second)
    }
  end

  def chat_thread_factory do
    %MessageThread{
      subject: nil,
      type: "chat",
      last_message_at: DateTime.utc_now() |> DateTime.truncate(:second)
    }
  end

  def message_thread_participant_factory do
    %MessageThreadParticipant{
      last_read_at: nil,
      deleted_at: nil,
      thread: build(:message_thread),
      user: build(:user)
    }
  end

  def message_factory do
    %Message{
      encrypted_body: "plaintext message for testing",
      ai_detection_status: "pending",
      ai_detection_score: nil,
      content_hash: :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower),
      thread: build(:message_thread),
      sender: build(:user)
    }
  end

  # ── Notifications ─────────────────────────────────────────────────────

  def notification_factory do
    %Notification{
      type: "friend_request",
      target_type: "friend_request",
      target_id: Ecto.UUID.generate(),
      read_at: nil,
      user: build(:user),
      actor: build(:user)
    }
  end

  # ── Privacy ───────────────────────────────────────────────────────────

  def privacy_setting_factory do
    %PrivacySetting{
      profile_visibility: "everyone",
      bio_visibility: "friends",
      interests_visibility: "friends",
      education_visibility: "friends",
      work_visibility: "friends",
      birthday_visibility: "friends",
      hometown_visibility: "friends",
      current_city_visibility: "friends",
      phone_visibility: "only_me",
      email_visibility: "only_me",
      relationship_visibility: "friends",
      wall_posting: "friends",
      friend_list_visibility: "friends",
      search_visible: true,
      user: build(:user)
    }
  end

  def block_factory do
    %Block{
      blocker: build(:user),
      blocked: build(:user)
    }
  end

  # ── Media ─────────────────────────────────────────────────────────

  def photo_album_factory do
    %PhotoAlbum{
      title: sequence(:album_title, &"Album #{&1}"),
      description: "A photo album",
      photo_count: 0,
      cover_photo_id: nil,
      user: build(:user)
    }
  end

  def photo_factory do
    %Photo{
      original_url: sequence(:photo_url, &"https://cdn.example.com/photos/album_photo_#{&1}.jpg"),
      thumb_200_url: sequence(:photo_thumb_200, &"https://cdn.example.com/photos/album_thumb200_#{&1}.jpg"),
      thumb_50_url: sequence(:photo_thumb_50, &"https://cdn.example.com/photos/album_thumb50_#{&1}.jpg"),
      caption: "A photo",
      position: 0,
      ai_detection_status: "pending",
      ai_detection_score: nil,
      content_hash: :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower),
      deleted_at: nil,
      user: build(:user),
      album: build(:photo_album)
    }
  end

  # ── AI Detection ──────────────────────────────────────────────────────

  def detection_result_factory do
    %DetectionResult{
      content_type: "wall_post",
      content_id: Ecto.UUID.generate(),
      provider: "gptzero",
      score: 0.15,
      raw_response: %{"completely_generated_prob" => 0.15},
      status: "pending",
      content_hash: :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower),
      user: build(:user)
    }
  end

  def detection_appeal_factory do
    %DetectionAppeal{
      explanation: "I wrote this myself without any AI assistance.",
      tools_used: "none",
      status: "pending",
      reviewed_at: nil,
      detection_result: build(:detection_result),
      user: build(:user),
      reviewed_by: nil
    }
  end
end
