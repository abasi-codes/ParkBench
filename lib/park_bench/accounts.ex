defmodule ParkBench.Accounts do
  @moduledoc "The Accounts context - user registration, auth, sessions, profiles"

  import Ecto.Query
  alias ParkBench.Repo

  alias ParkBench.Accounts.{
    User,
    Session,
    EmailVerificationToken,
    PasswordResetToken,
    UserProfile,
    ProfilePhoto,
    EducationEntry,
    WorkEntry
  }

  alias ParkBench.AIDetection

  # ──────────────────────────────────────────────
  # User Registration
  # ──────────────────────────────────────────────

  def register_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  def get_user!(id), do: Repo.get!(User, id)

  def get_user(id), do: Repo.get(User, id)

  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: String.downcase(email))
  end

  def get_user_by_slug(slug) when is_binary(slug) do
    Repo.get_by(User, slug: slug)
  end

  # ──────────────────────────────────────────────
  # Authentication
  # ──────────────────────────────────────────────

  def authenticate_user(email, password) do
    user = get_user_by_email(email)

    cond do
      is_nil(user) ->
        Argon2.no_user_verify()
        {:error, :invalid_credentials}

      account_locked?(user) ->
        {:error, :account_locked}

      User.valid_password?(user, password) ->
        # Reset failed attempts on success
        if user.failed_login_attempts > 0 do
          user |> User.unlock_changeset() |> Repo.update()
        end

        {:ok, user}

      true ->
        user = user |> User.failed_login_changeset() |> Repo.update!()
        maybe_lock_account(user)
        {:error, :invalid_credentials}
    end
  end

  defp account_locked?(%User{locked_at: nil}), do: false

  defp account_locked?(%User{locked_at: locked_at} = user) do
    unlock_at = DateTime.add(locked_at, lockout_duration(user), :second)
    DateTime.compare(DateTime.utc_now(), unlock_at) == :lt
  end

  defp lockout_duration(user) do
    cond do
      user.failed_login_attempts >= 10 -> 3600
      user.failed_login_attempts >= 5 -> 900
      true -> 0
    end
  end

  defp maybe_lock_account(user) do
    if user.failed_login_attempts >= 5 do
      user |> User.lock_changeset() |> Repo.update()
    end
  end

  # ──────────────────────────────────────────────
  # Sessions
  # ──────────────────────────────────────────────

  @max_sessions 5

  def create_session(user, ip_address \\ nil, user_agent \\ nil) do
    # Enforce max sessions per user
    prune_excess_sessions(user.id, @max_sessions - 1)

    raw_token = :crypto.strong_rand_bytes(32)
    token_hash = :crypto.hash(:sha256, raw_token) |> Base.encode64()

    %Session{}
    |> Session.changeset(%{
      user_id: user.id,
      token_hash: token_hash,
      ip_address: ip_address,
      user_agent: if(user_agent, do: String.slice(user_agent, 0..499)),
      expires_at:
        DateTime.utc_now()
        |> DateTime.add(7 * 24 * 3600, :second)
        |> DateTime.truncate(:second),
      last_active_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
    |> Repo.insert()
    |> case do
      {:ok, session} -> {:ok, Base.encode64(raw_token), session}
      error -> error
    end
  end

  def get_user_by_session_token(raw_token) when is_binary(raw_token) do
    with {:ok, decoded} <- Base.decode64(raw_token),
         token_hash = :crypto.hash(:sha256, decoded) |> Base.encode64() do
      Session
      |> join(:inner, [s], u in User, on: s.user_id == u.id)
      |> where([s, _u], s.token_hash == ^token_hash)
      |> where([s, _u], s.expires_at > ^DateTime.utc_now())
      |> select([_s, u], u)
      |> Repo.one()
    else
      _ -> nil
    end
  end

  def get_user_by_session_token(_), do: nil

  def delete_session(raw_token) when is_binary(raw_token) do
    with {:ok, decoded} <- Base.decode64(raw_token),
         token_hash = :crypto.hash(:sha256, decoded) |> Base.encode64() do
      Session
      |> where([s], s.token_hash == ^token_hash)
      |> Repo.delete_all()
    end

    :ok
  end

  def delete_session(_), do: :ok

  def delete_all_sessions(user_id) do
    Session
    |> where([s], s.user_id == ^user_id)
    |> Repo.delete_all()
  end

  defp prune_excess_sessions(user_id, max_keep) do
    sessions =
      Session
      |> where([s], s.user_id == ^user_id)
      |> order_by([s], desc: s.last_active_at)
      |> Repo.all()

    if length(sessions) >= max_keep do
      to_delete = Enum.drop(sessions, max_keep)
      ids = Enum.map(to_delete, & &1.id)
      Session |> where([s], s.id in ^ids) |> Repo.delete_all()
    end
  end

  # ──────────────────────────────────────────────
  # Email Verification
  # ──────────────────────────────────────────────

  def create_email_verification_token(user) do
    token = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)

    %EmailVerificationToken{}
    |> EmailVerificationToken.changeset(%{
      user_id: user.id,
      token: token,
      expires_at:
        DateTime.utc_now()
        |> DateTime.add(24 * 3600, :second)
        |> DateTime.truncate(:second)
    })
    |> Repo.insert()
    |> case do
      {:ok, _record} -> {:ok, token}
      error -> error
    end
  end

  def verify_email(token) when is_binary(token) do
    now = DateTime.utc_now()

    verification =
      EmailVerificationToken
      |> where([t], t.token == ^token)
      |> where([t], is_nil(t.used_at))
      |> where([t], t.expires_at > ^now)
      |> Repo.one()

    case verification do
      nil ->
        {:error, :invalid_token}

      record ->
        Repo.transaction(fn ->
          record
          |> Ecto.Changeset.change(used_at: DateTime.truncate(now, :second))
          |> Repo.update!()

          user = get_user!(record.user_id)
          user |> User.verify_email_changeset() |> Repo.update!()
        end)
    end
  end

  # ──────────────────────────────────────────────
  # Password Reset
  # ──────────────────────────────────────────────

  def create_password_reset_token(email) do
    case get_user_by_email(email) do
      nil ->
        # Don't reveal whether the user exists
        {:ok, :noop}

      user ->
        token = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)

        %PasswordResetToken{}
        |> PasswordResetToken.changeset(%{
          user_id: user.id,
          token: token,
          expires_at:
            DateTime.utc_now()
            |> DateTime.add(3600, :second)
            |> DateTime.truncate(:second)
        })
        |> Repo.insert()
        |> case do
          {:ok, _} -> {:ok, token}
          error -> error
        end
    end
  end

  def reset_password(token, new_password, new_password_confirmation) do
    now = DateTime.utc_now()

    reset =
      PasswordResetToken
      |> where([t], t.token == ^token)
      |> where([t], is_nil(t.used_at))
      |> where([t], t.expires_at > ^now)
      |> Repo.one()

    case reset do
      nil ->
        {:error, :invalid_token}

      record ->
        Repo.transaction(fn ->
          record
          |> Ecto.Changeset.change(used_at: DateTime.truncate(now, :second))
          |> Repo.update!()

          user = get_user!(record.user_id)

          user
          |> User.password_changeset(%{
            password: new_password,
            password_confirmation: new_password_confirmation
          })
          |> Repo.update!()

          # Invalidate all sessions after password change
          delete_all_sessions(user.id)
        end)
    end
  end

  # ──────────────────────────────────────────────
  # Account Updates
  # ──────────────────────────────────────────────

  def update_display_name(user, new_name) do
    user
    |> Ecto.Changeset.cast(%{display_name: new_name}, [:display_name])
    |> Ecto.Changeset.validate_required([:display_name])
    |> Ecto.Changeset.validate_length(:display_name, min: 1, max: 100)
    |> Repo.update()
  end

  def change_password(user, current_password, new_password, new_password_confirmation) do
    if User.valid_password?(user, current_password) do
      user
      |> User.password_changeset(%{
        password: new_password,
        password_confirmation: new_password_confirmation
      })
      |> Repo.update()
    else
      {:error, :invalid_current_password}
    end
  end

  def change_email(user, new_email, current_password) do
    if User.valid_password?(user, current_password) do
      user
      |> Ecto.Changeset.cast(%{email: new_email}, [:email])
      |> Ecto.Changeset.validate_required([:email])
      |> Ecto.Changeset.validate_format(:email, ~r/^[^\s]+@[^\s]+\.[^\s]+$/,
        message: "must be a valid email address"
      )
      |> Ecto.Changeset.validate_length(:email, max: 254)
      |> Ecto.Changeset.update_change(:email, &String.downcase/1)
      |> Ecto.Changeset.unique_constraint(:email)
      |> Repo.update()
    else
      {:error, :invalid_current_password}
    end
  end

  def delete_account(user, password) do
    if User.valid_password?(user, password) do
      delete_all_sessions(user.id)
      Repo.delete(user)
    else
      {:error, :invalid_current_password}
    end
  end

  # ──────────────────────────────────────────────
  # Profiles
  # ──────────────────────────────────────────────

  def get_profile(user_id) do
    Repo.get(UserProfile, user_id)
  end

  def get_or_create_profile(user_id) do
    case get_profile(user_id) do
      nil ->
        %UserProfile{user_id: user_id}
        |> Repo.insert()

      profile ->
        {:ok, profile}
    end
  end

  def update_profile(user_id, attrs) do
    case get_or_create_profile(user_id) do
      {:ok, profile} ->
        profile
        |> UserProfile.changeset(attrs)
        |> Repo.update()

      error ->
        error
    end
  end

  def update_cover_photo(user_id, cover_photo_url) do
    case update_profile(user_id, %{cover_photo_url: cover_photo_url}) do
      {:ok, profile} ->
        ParkBench.Timeline.create_feed_item(%{
          user_id: user_id,
          item_type: "profile_updated",
          content_id: user_id
        })

        friend_ids = ParkBench.Social.list_friends(user_id) |> Enum.map(& &1.id)

        for friend_id <- friend_ids do
          Phoenix.PubSub.broadcast(
            ParkBench.PubSub,
            "feed:#{friend_id}",
            {:new_feed_item, user_id}
          )
        end

        {:ok, profile}

      error ->
        error
    end
  end

  # ──────────────────────────────────────────────
  # Profile Photos
  # ──────────────────────────────────────────────

  def create_profile_photo(user_id, attrs) do
    # Set all existing photos to not current
    from(p in ProfilePhoto, where: p.user_id == ^user_id and p.is_current == true)
    |> Repo.update_all(set: [is_current: false])

    %ProfilePhoto{}
    |> ProfilePhoto.changeset(Map.merge(attrs, %{user_id: user_id, is_current: true}))
    |> Repo.insert()
    |> case do
      {:ok, photo} ->
        ParkBench.Timeline.create_feed_item(%{
          user_id: user_id,
          item_type: "profile_photo_updated",
          content_id: photo.id
        })

        friend_ids = ParkBench.Social.list_friends(user_id) |> Enum.map(& &1.id)

        for friend_id <- friend_ids do
          Phoenix.PubSub.broadcast(
            ParkBench.PubSub,
            "feed:#{friend_id}",
            {:new_feed_item, photo.id}
          )
        end

        {:ok, photo}

      error ->
        error
    end
  end

  def get_current_profile_photo(user_id) do
    ProfilePhoto
    |> where([p], p.user_id == ^user_id and p.is_current == true)
    |> Repo.one()
  end

  @doc """
  Upload a profile photo from a local file path.

  1. Uploads original to S3 (photos/originals/{user_id}/{uuid}.jpg)
  2. Creates ProfilePhoto record with original_url, is_current: true
  3. Marks previous photos as is_current: false
  4. Enqueues PhotoProcessingWorker via Oban
  """
  def upload_profile_photo(user_id, file_path) do
    bucket = Application.get_env(:park_bench, :s3_bucket)
    uuid = Ecto.UUID.generate()
    s3_key = "photos/originals/#{user_id}/#{uuid}.jpg"

    with {:ok, _} <- upload_to_s3(file_path, bucket, s3_key) do
      original_url = "/uploads/#{s3_key}"
      content_hash = hash_file(file_path)

      case create_profile_photo(user_id, %{
             original_url: original_url,
             content_hash: content_hash
           }) do
        {:ok, photo} ->
          Oban.insert(
            ParkBench.Workers.PhotoProcessingWorker.new(%{
              "photo_id" => photo.id,
              "file_path" => file_path
            })
          )

          AIDetection.check_image(user_id, "profile_photo", photo.id, original_url)

          {:ok, photo}

        error ->
          error
      end
    end
  end

  defp upload_to_s3(file_path, bucket, key) do
    file_path
    |> ExAws.S3.Upload.stream_file()
    |> ExAws.S3.upload(bucket, key, content_type: "image/jpeg")
    |> ExAws.request()
  end

  defp hash_file(file_path) do
    File.stream!(file_path, 2048)
    |> Enum.reduce(:crypto.hash_init(:sha256), &:crypto.hash_update(&2, &1))
    |> :crypto.hash_final()
    |> Base.encode16(case: :lower)
  end

  # ──────────────────────────────────────────────
  # Education Entries
  # ──────────────────────────────────────────────

  def list_education_entries(user_id) do
    EducationEntry
    |> where([e], e.user_id == ^user_id)
    |> order_by([e], desc: e.end_year)
    |> Repo.all()
  end

  def create_education_entry(user_id, attrs) do
    %EducationEntry{}
    |> EducationEntry.changeset(Map.put(attrs, "user_id", user_id))
    |> Repo.insert()
  end

  def update_education_entry(id, attrs) do
    Repo.get!(EducationEntry, id)
    |> EducationEntry.changeset(attrs)
    |> Repo.update()
  end

  def delete_education_entry(id) do
    Repo.get!(EducationEntry, id) |> Repo.delete()
  end

  # ──────────────────────────────────────────────
  # Work Entries
  # ──────────────────────────────────────────────

  def list_work_entries(user_id) do
    WorkEntry
    |> where([e], e.user_id == ^user_id)
    |> order_by([e], desc: e.is_current, desc: e.start_date)
    |> Repo.all()
  end

  def create_work_entry(user_id, attrs) do
    %WorkEntry{}
    |> WorkEntry.changeset(Map.put(attrs, "user_id", user_id))
    |> Repo.insert()
  end

  def update_work_entry(id, attrs) do
    Repo.get!(WorkEntry, id)
    |> WorkEntry.changeset(attrs)
    |> Repo.update()
  end

  def delete_work_entry(id) do
    Repo.get!(WorkEntry, id) |> Repo.delete()
  end

  # ──────────────────────────────────────────────
  # User Search
  # ──────────────────────────────────────────────

  def search_users(query, opts \\ []) do
    limit = Keyword.get(opts, :limit, 30)
    current_user_id = Keyword.get(opts, :current_user_id)

    base =
      User
      |> where(
        [u],
        ilike(u.display_name, ^"%#{sanitize_like(query)}%") or
          ilike(u.email, ^"%#{sanitize_like(query)}%")
      )
      |> where([u], not is_nil(u.email_verified_at))
      |> limit(^limit)

    base =
      if current_user_id do
        base |> where([u], u.id != ^current_user_id)
      else
        base
      end

    Repo.all(base)
  end

  def search_users_autocomplete(query, current_user_id) do
    User
    |> where([u], ilike(u.display_name, ^"#{sanitize_like(query)}%"))
    |> where([u], u.id != ^current_user_id)
    |> where([u], not is_nil(u.email_verified_at))
    |> limit(5)
    |> select([u], %{id: u.id, display_name: u.display_name, slug: u.slug})
    |> Repo.all()
  end

  defp sanitize_like(query) do
    query
    |> String.replace("\\", "\\\\")
    |> String.replace("%", "\\%")
    |> String.replace("_", "\\_")
  end

  # ──────────────────────────────────────────────
  # Bench Streak & Last Seen
  # ──────────────────────────────────────────────

  def record_daily_activity(user_id) do
    today = Date.utc_today()

    case get_or_create_profile(user_id) do
      {:ok, profile} ->
        cond do
          profile.last_active_date == today ->
            {:ok, profile}

          profile.last_active_date == Date.add(today, -1) ->
            profile
            |> Ecto.Changeset.change(
              bench_streak: (profile.bench_streak || 0) + 1,
              last_active_date: today
            )
            |> Repo.update()

          true ->
            profile
            |> Ecto.Changeset.change(bench_streak: 1, last_active_date: today)
            |> Repo.update()
        end

      error ->
        error
    end
  end

  def get_bench_streak(user_id) do
    case get_profile(user_id) do
      nil -> 0
      profile -> profile.bench_streak || 0
    end
  end

  def update_last_seen(user_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    User
    |> where([u], u.id == ^user_id)
    |> Repo.update_all(set: [last_seen_at: now])
  end

  # ──────────────────────────────────────────────
  # Onboarding
  # ──────────────────────────────────────────────

  def mark_onboarding_complete(user) do
    user
    |> User.onboarding_changeset()
    |> Repo.update()
  end

  # ──────────────────────────────────────────────
  # Privacy Helper
  # ──────────────────────────────────────────────

  def visible_to?(field_visibility, viewer_id, owner_id) do
    cond do
      viewer_id == owner_id -> true
      field_visibility == "everyone" -> true
      field_visibility == "only_me" -> false
      field_visibility == "friends" -> ParkBench.Social.friends?(owner_id, viewer_id)
      true -> false
    end
  end
end
