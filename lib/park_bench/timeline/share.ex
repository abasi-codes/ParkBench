defmodule ParkBench.Timeline.Share do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "shares" do
    belongs_to :user, ParkBench.Accounts.User
    belongs_to :wall_post, ParkBench.Timeline.WallPost

    timestamps(type: :utc_datetime)
  end

  def changeset(share, attrs) do
    share
    |> cast(attrs, [:user_id, :wall_post_id])
    |> validate_required([:user_id, :wall_post_id])
    |> unique_constraint([:user_id, :wall_post_id])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:wall_post_id)
  end
end
