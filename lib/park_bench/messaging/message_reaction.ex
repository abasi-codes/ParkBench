defmodule ParkBench.Messaging.MessageReaction do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @valid_emojis ["thumbs_up", "heart", "laugh", "wow", "sad", "angry"]

  schema "message_reactions" do
    field :emoji, :string

    belongs_to :message, ParkBench.Messaging.Message
    belongs_to :user, ParkBench.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(reaction, attrs) do
    reaction
    |> cast(attrs, [:message_id, :user_id, :emoji])
    |> validate_required([:message_id, :user_id, :emoji])
    |> validate_inclusion(:emoji, @valid_emojis)
    |> unique_constraint([:message_id, :user_id, :emoji])
    |> foreign_key_constraint(:message_id)
    |> foreign_key_constraint(:user_id)
  end
end
