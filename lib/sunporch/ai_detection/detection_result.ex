defmodule Sunporch.AIDetection.DetectionResult do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @valid_content_types ~w(wall_post comment status_update message profile_photo)
  @valid_providers ~w(gptzero hive exempt cache)
  @valid_statuses ~w(pending approved soft_rejected hard_rejected needs_review appealed)

  schema "ai_detection_results" do
    field :content_type, :string
    field :content_id, :binary_id
    field :provider, :string
    field :score, :float
    field :raw_response, :map
    field :status, :string, default: "pending"
    field :content_hash, :string

    belongs_to :user, Sunporch.Accounts.User

    has_many :appeals, Sunporch.AIDetection.DetectionAppeal, foreign_key: :detection_result_id

    timestamps(type: :utc_datetime)
  end

  def changeset(result, attrs) do
    result
    |> cast(attrs, [:user_id, :content_type, :content_id, :provider, :score, :raw_response, :status, :content_hash])
    |> validate_required([:user_id, :content_type, :content_id, :provider])
    |> validate_inclusion(:content_type, @valid_content_types)
    |> validate_inclusion(:provider, @valid_providers)
    |> validate_inclusion(:status, @valid_statuses)
    |> foreign_key_constraint(:user_id)
  end
end
