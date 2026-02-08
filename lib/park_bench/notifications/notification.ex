defmodule ParkBench.Notifications.Notification do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @valid_types [
    "friend_request",
    "friend_accept",
    "wall_post",
    "wall_comment",
    "post_comment",
    "new_message",
    "poke",
    "photo_tag",
    "ai_content_flagged",
    "ai_appeal_resolved"
  ]

  @valid_target_types [
    "user",
    "wall_post",
    "comment",
    "message_thread",
    "WallPost",
    "Comment",
    "FriendRequest",
    "Poke",
    "Message",
    "DetectionResult",
    "StatusUpdate"
  ]

  schema "notifications" do
    field :type, :string
    field :target_type, :string
    field :target_id, :binary_id
    field :read_at, :utc_datetime

    belongs_to :user, ParkBench.Accounts.User
    belongs_to :actor, ParkBench.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(notification, attrs) do
    notification
    |> cast(attrs, [:user_id, :actor_id, :type, :target_type, :target_id])
    |> validate_required([:user_id, :actor_id, :type])
    |> validate_inclusion(:type, @valid_types)
    |> validate_inclusion(:target_type, @valid_target_types)
    |> validate_not_self_notification()
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:actor_id)
  end

  def mark_read_changeset(notification) do
    change(notification, read_at: DateTime.utc_now() |> DateTime.truncate(:second))
  end

  def read?(%__MODULE__{read_at: read_at}), do: not is_nil(read_at)

  defp validate_not_self_notification(changeset) do
    user_id = get_field(changeset, :user_id)
    actor_id = get_field(changeset, :actor_id)

    if user_id == actor_id do
      add_error(changeset, :actor_id, "cannot send a notification to yourself")
    else
      changeset
    end
  end
end
