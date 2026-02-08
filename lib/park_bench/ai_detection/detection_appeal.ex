defmodule ParkBench.AIDetection.DetectionAppeal do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @valid_statuses ~w(pending approved denied)

  schema "ai_detection_appeals" do
    field :explanation, :string
    field :tools_used, :string
    field :status, :string, default: "pending"
    field :reviewed_at, :utc_datetime

    belongs_to :detection_result, ParkBench.AIDetection.DetectionResult
    belongs_to :user, ParkBench.Accounts.User
    belongs_to :reviewed_by, ParkBench.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(appeal, attrs) do
    appeal
    |> cast(attrs, [:detection_result_id, :user_id, :explanation, :tools_used])
    |> validate_required([:detection_result_id, :user_id, :explanation])
    |> validate_length(:explanation, min: 1, max: 1000)
    |> validate_length(:tools_used, max: 500)
    |> foreign_key_constraint(:detection_result_id)
    |> foreign_key_constraint(:user_id)
  end

  def review_changeset(appeal, attrs) do
    appeal
    |> cast(attrs, [:status, :reviewed_by_id, :reviewed_at])
    |> validate_required([:status, :reviewed_by_id])
    |> validate_inclusion(:status, @valid_statuses)
    |> foreign_key_constraint(:reviewed_by_id)
  end
end
