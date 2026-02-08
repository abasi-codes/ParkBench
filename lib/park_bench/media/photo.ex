defmodule ParkBench.Media.Photo do
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

  schema "photos" do
    field :original_url, :string
    field :thumb_200_url, :string
    field :thumb_50_url, :string
    field :caption, :string
    field :position, :integer, default: 0
    field :ai_detection_status, :string, default: "pending"
    field :ai_detection_score, :float
    field :content_hash, :string
    field :deleted_at, :utc_datetime

    belongs_to :user, ParkBench.Accounts.User
    belongs_to :album, ParkBench.Media.PhotoAlbum

    timestamps(type: :utc_datetime)
  end

  def changeset(photo, attrs) do
    photo
    |> cast(attrs, [
      :user_id,
      :album_id,
      :original_url,
      :thumb_200_url,
      :thumb_50_url,
      :caption,
      :position,
      :ai_detection_status,
      :ai_detection_score,
      :content_hash,
      :deleted_at
    ])
    |> validate_required([:user_id, :album_id, :original_url])
    |> validate_length(:original_url, max: 500)
    |> validate_length(:caption, max: 500)
    |> validate_length(:content_hash, max: 64)
    |> validate_inclusion(:ai_detection_status, @valid_ai_detection_statuses)
    |> validate_number(:ai_detection_score,
      greater_than_or_equal_to: 0.0,
      less_than_or_equal_to: 1.0
    )
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:album_id)
  end

  def ai_detection_changeset(photo, attrs) do
    photo
    |> cast(attrs, [:ai_detection_status, :ai_detection_score])
    |> validate_required([:ai_detection_status])
    |> validate_inclusion(:ai_detection_status, @valid_ai_detection_statuses)
    |> validate_number(:ai_detection_score,
      greater_than_or_equal_to: 0.0,
      less_than_or_equal_to: 1.0
    )
  end
end
