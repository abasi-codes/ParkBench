defmodule ParkBench.Messaging.MessageThread do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "message_threads" do
    field :subject, :string
    field :type, :string, default: "inbox"
    field :last_message_at, :utc_datetime

    has_many :participants, ParkBench.Messaging.MessageThreadParticipant, foreign_key: :thread_id
    has_many :messages, ParkBench.Messaging.Message, foreign_key: :thread_id

    timestamps(type: :utc_datetime)
  end

  def changeset(thread, attrs) do
    thread
    |> cast(attrs, [:subject, :type, :last_message_at])
    |> validate_length(:subject, max: 255)
    |> validate_inclusion(:type, ["inbox", "chat"])
  end

  def update_last_message_changeset(thread) do
    change(thread, last_message_at: DateTime.utc_now() |> DateTime.truncate(:second))
  end
end
