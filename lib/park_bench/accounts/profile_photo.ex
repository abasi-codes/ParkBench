defmodule ParkBench.Accounts.ProfilePhoto do
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

  schema "profile_photos" do
    field :original_url, :string
    field :thumb_200_url, :string
    field :thumb_50_url, :string
    field :is_current, :boolean, default: false
    field :ai_detection_status, :string, default: "pending"
    field :ai_detection_score, :float
    field :content_hash, :string

    belongs_to :user, ParkBench.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(photo, attrs) do
    photo
    |> cast(attrs, [
      :user_id,
      :original_url,
      :thumb_200_url,
      :thumb_50_url,
      :is_current,
      :ai_detection_status,
      :ai_detection_score,
      :content_hash
    ])
    |> validate_required([:user_id, :original_url])
    |> validate_length(:original_url, max: 500)
    |> validate_length(:thumb_200_url, max: 500)
    |> validate_length(:thumb_50_url, max: 500)
    |> validate_length(:content_hash, max: 64)
    |> validate_inclusion(:ai_detection_status, @valid_ai_detection_statuses)
    |> validate_number(:ai_detection_score,
      greater_than_or_equal_to: 0.0,
      less_than_or_equal_to: 1.0
    )
    |> foreign_key_constraint(:user_id)
  end

  def set_current_changeset(photo) do
    change(photo, is_current: true)
  end

  def unset_current_changeset(photo) do
    change(photo, is_current: false)
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
