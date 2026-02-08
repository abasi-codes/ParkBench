defmodule ParkBench.Messaging.MessageThreadParticipant do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "message_thread_participants" do
    field :last_read_at, :utc_datetime
    field :deleted_at, :utc_datetime

    belongs_to :thread, ParkBench.Messaging.MessageThread
    belongs_to :user, ParkBench.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(participant, attrs) do
    participant
    |> cast(attrs, [:thread_id, :user_id, :last_read_at, :deleted_at])
    |> validate_required([:thread_id, :user_id])
    |> unique_constraint([:thread_id, :user_id],
      name: :message_thread_participants_thread_id_user_id_index
    )
    |> foreign_key_constraint(:thread_id)
    |> foreign_key_constraint(:user_id)
  end

  def mark_read_changeset(participant) do
    change(participant, last_read_at: DateTime.utc_now() |> DateTime.truncate(:second))
  end

  def soft_delete_changeset(participant) do
    change(participant, deleted_at: DateTime.utc_now() |> DateTime.truncate(:second))
  end

  def deleted?(%__MODULE__{deleted_at: deleted_at}), do: not is_nil(deleted_at)

  def has_unread?(%__MODULE__{last_read_at: nil}), do: true

  def has_unread?(%__MODULE__{last_read_at: last_read_at} = participant) do
    thread = participant.thread

    case thread do
      %{last_message_at: nil} ->
        false

      %{last_message_at: last_message_at} ->
        DateTime.compare(last_message_at, last_read_at) == :gt

      _ ->
        false
    end
  end
end
