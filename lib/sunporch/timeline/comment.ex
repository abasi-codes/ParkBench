defmodule Sunporch.Timeline.Comment do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @valid_commentable_types ["WallPost", "StatusUpdate", "ProfilePhoto"]
  @valid_ai_detection_statuses ["pending", "approved", "soft_rejected", "hard_rejected", "needs_review", "appealed"]

  schema "comments" do
    field :commentable_type, :string
    field :commentable_id, :binary_id
    field :body, :string
    field :ai_detection_status, :string, default: "pending"
    field :ai_detection_score, :float
    field :content_hash, :string
    field :deleted_at, :utc_datetime

    belongs_to :author, Sunporch.Accounts.User

    has_many :likes, Sunporch.Timeline.Like,
      foreign_key: :likeable_id,
      where: [likeable_type: "Comment"]

    timestamps(type: :utc_datetime)
  end

  def changeset(comment, attrs) do
    comment
    |> cast(attrs, [:author_id, :commentable_type, :commentable_id, :body])
    |> validate_required([:author_id, :commentable_type, :commentable_id, :body])
    |> validate_length(:body, min: 1, max: 2000)
    |> validate_inclusion(:commentable_type, @valid_commentable_types)
    |> generate_content_hash()
    |> foreign_key_constraint(:author_id)
  end

  def ai_detection_changeset(comment, attrs) do
    comment
    |> cast(attrs, [:ai_detection_status, :ai_detection_score])
    |> validate_required([:ai_detection_status])
    |> validate_inclusion(:ai_detection_status, @valid_ai_detection_statuses)
    |> validate_number(:ai_detection_score, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
  end

  def soft_delete_changeset(comment) do
    change(comment, deleted_at: DateTime.utc_now() |> DateTime.truncate(:second))
  end

  def deleted?(%__MODULE__{deleted_at: deleted_at}), do: not is_nil(deleted_at)

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
