defmodule Sunporch.Messaging.Message do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @valid_ai_detection_statuses ["pending", "approved", "soft_rejected", "hard_rejected", "needs_review", "appealed"]

  schema "messages" do
    field :encrypted_body, :binary
    field :ai_detection_status, :string, default: "pending"
    field :ai_detection_score, :float
    field :content_hash, :string

    # Virtual field for decrypted text
    field :body, :string, virtual: true

    belongs_to :thread, Sunporch.Messaging.MessageThread
    belongs_to :sender, Sunporch.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(message, attrs) do
    message
    |> cast(attrs, [:thread_id, :sender_id, :body])
    |> validate_required([:thread_id, :sender_id, :body])
    |> validate_length(:body, min: 1, max: 10_000)
    |> generate_content_hash()
    |> encrypt_body()
    |> foreign_key_constraint(:thread_id)
    |> foreign_key_constraint(:sender_id)
  end

  def ai_detection_changeset(message, attrs) do
    message
    |> cast(attrs, [:ai_detection_status, :ai_detection_score])
    |> validate_required([:ai_detection_status])
    |> validate_inclusion(:ai_detection_status, @valid_ai_detection_statuses)
    |> validate_number(:ai_detection_score, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
  end

  defp generate_content_hash(changeset) do
    case get_change(changeset, :body) do
      nil ->
        changeset

      body ->
        hash = :crypto.hash(:sha256, body) |> Base.encode16(case: :lower)
        put_change(changeset, :content_hash, hash)
    end
  end

  defp encrypt_body(changeset) do
    case get_change(changeset, :body) do
      nil ->
        changeset

      body ->
        changeset
        |> put_change(:encrypted_body, Sunporch.Messaging.encrypt_message(body))
        |> delete_change(:body)
    end
  end
end
