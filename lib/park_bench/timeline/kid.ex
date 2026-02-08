defmodule ParkBench.Timeline.Kid do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "kids" do
    field :name, :string
    field :age_years, :integer
    field :emoji, :string, default: "\u{1F476}"
    field :current_activity, :string
    field :deleted_at, :utc_datetime

    belongs_to :user, ParkBench.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(kid, attrs) do
    kid
    |> cast(attrs, [:user_id, :name, :age_years, :emoji, :current_activity])
    |> validate_required([:user_id, :name])
    |> validate_length(:name, min: 1, max: 50)
    |> validate_length(:current_activity, max: 255)
    |> validate_number(:age_years, greater_than_or_equal_to: 0, less_than_or_equal_to: 18)
    |> foreign_key_constraint(:user_id)
  end
end
