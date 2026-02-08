defmodule ParkBench.Timeline.StatusUpdate do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @valid_ai_detection_statuses [
    "pending",
    "approved",
    "soft_rejected",
    "hard_rejected",
    "needs_review",
    "appealed"
  ]

  schema "status_updates" do
    field :body, :string
    field :ai_detection_status, :string, default: "pending"
    field :ai_detection_score, :float
    field :content_hash, :string

    belongs_to :user, ParkBench.Accounts.User

    has_many :comments, ParkBench.Timeline.Comment,
      foreign_key: :commentable_id,
      where: [commentable_type: "StatusUpdate"]

    has_many :likes, ParkBench.Timeline.Like,
      foreign_key: :likeable_id,
      where: [likeable_type: "StatusUpdate"]

    timestamps(type: :utc_datetime)
  end

  def changeset(status_update, attrs) do
    status_update
    |> cast(attrs, [:user_id, :body])
    |> validate_required([:user_id, :body])
    |> validate_length(:body, min: 1, max: 160)
    |> generate_content_hash()
    |> foreign_key_constraint(:user_id)
  end

  def ai_detection_changeset(status_update, attrs) do
    status_update
    |> cast(attrs, [:ai_detection_status, :ai_detection_score])
    |> validate_required([:ai_detection_status])
    |> validate_inclusion(:ai_detection_status, @valid_ai_detection_statuses)
    |> validate_number(:ai_detection_score,
      greater_than_or_equal_to: 0.0,
      less_than_or_equal_to: 1.0
    )
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
end
