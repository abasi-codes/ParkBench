defmodule ParkBench.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "users" do
    field :email, :string
    field :display_name, :string
    field :hashed_password, :string
    field :slug, :string
    field :role, :string, default: "user"
    field :email_verified_at, :utc_datetime
    field :locked_at, :utc_datetime
    field :failed_login_attempts, :integer, default: 0
    field :last_failed_login_at, :utc_datetime
    field :ai_flagged, :boolean, default: false
    field :ai_leniency_boost, :float, default: 0.0
    field :onboarding_completed_at, :utc_datetime
    field :last_seen_at, :utc_datetime

    # Virtual fields
    field :password, :string, virtual: true
    field :password_confirmation, :string, virtual: true

    has_one :profile, ParkBench.Accounts.UserProfile
    has_one :privacy_settings, ParkBench.Privacy.PrivacySetting
    has_many :profile_photos, ParkBench.Accounts.ProfilePhoto
    has_many :education_entries, ParkBench.Accounts.EducationEntry
    has_many :work_entries, ParkBench.Accounts.WorkEntry
    has_many :sessions, ParkBench.Accounts.Session
    has_many :wall_posts_authored, ParkBench.Timeline.WallPost, foreign_key: :author_id
    has_many :wall_posts_received, ParkBench.Timeline.WallPost, foreign_key: :wall_owner_id
    has_many :status_updates, ParkBench.Timeline.StatusUpdate
    has_many :notifications, ParkBench.Notifications.Notification
    has_many :feed_items, ParkBench.Timeline.FeedItem
    has_many :pets, ParkBench.Timeline.Pet
    has_many :kids, ParkBench.Timeline.Kid

    timestamps(type: :utc_datetime)
  end

  def registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :display_name, :password, :password_confirmation])
    |> validate_required([:email, :display_name, :password, :password_confirmation])
    |> validate_email()
    |> validate_password()
    |> validate_display_name()
    |> generate_slug()
    |> hash_password()
  end

  def login_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :password])
    |> validate_required([:email, :password])
  end

  def admin_changeset(user, attrs) do
    user
    |> cast(attrs, [:role, :ai_flagged, :ai_leniency_boost, :locked_at])
  end

  def verify_email_changeset(user) do
    change(user, email_verified_at: DateTime.utc_now() |> DateTime.truncate(:second))
  end

  def lock_changeset(user) do
    change(user, locked_at: DateTime.utc_now() |> DateTime.truncate(:second))
  end

  def unlock_changeset(user) do
    change(user, locked_at: nil, failed_login_attempts: 0)
  end

  def failed_login_changeset(user) do
    change(user,
      failed_login_attempts: (user.failed_login_attempts || 0) + 1,
      last_failed_login_at: DateTime.utc_now() |> DateTime.truncate(:second)
    )
  end

  def onboarding_changeset(user) do
    change(user, onboarding_completed_at: DateTime.utc_now() |> DateTime.truncate(:second))
  end

  def password_changeset(user, attrs) do
    user
    |> cast(attrs, [:password, :password_confirmation])
    |> validate_required([:password, :password_confirmation])
    |> validate_password()
    |> hash_password()
  end

  defp validate_email(changeset) do
    changeset
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+\.[^\s]+$/,
      message: "must be a valid email address"
    )
    |> validate_length(:email, max: 254)
    |> update_change(:email, &String.downcase/1)
    |> unique_constraint(:email)
  end

  defp validate_password(changeset) do
    changeset
    |> validate_length(:password, min: 8, max: 72)
    |> validate_confirmation(:password, message: "does not match password")
  end

  defp validate_display_name(changeset) do
    changeset
    |> validate_length(:display_name, min: 2, max: 100)
    |> validate_format(:display_name, ~r/^[a-zA-Z0-9\s\-'\.]+$/,
      message: "can only contain letters, numbers, spaces, hyphens, apostrophes, and periods"
    )
  end

  defp generate_slug(changeset) do
    case get_change(changeset, :display_name) do
      nil ->
        changeset

      name ->
        base_slug =
          name
          |> String.downcase()
          |> String.replace(~r/[^a-z0-9\s-]/, "")
          |> String.replace(~r/\s+/, "-")
          |> String.trim("-")

        slug =
          "#{base_slug}-#{:crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)}"

        put_change(changeset, :slug, slug)
    end
  end

  defp hash_password(changeset) do
    case get_change(changeset, :password) do
      nil ->
        changeset

      password ->
        changeset
        |> put_change(:hashed_password, Argon2.hash_pwd_salt(password))
        |> delete_change(:password)
        |> delete_change(:password_confirmation)
    end
  end

  def valid_password?(%__MODULE__{hashed_password: hashed}, password)
      when is_binary(hashed) and is_binary(password) do
    Argon2.verify_pass(password, hashed)
  end

  def valid_password?(_, _) do
    Argon2.no_user_verify()
    false
  end
end
