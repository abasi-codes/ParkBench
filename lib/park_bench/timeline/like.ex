defmodule ParkBench.Timeline.Like do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @valid_likeable_types ["WallPost", "Comment", "StatusUpdate", "ProfilePhoto"]

  schema "likes" do
    field :likeable_type, :string
    field :likeable_id, :binary_id

    belongs_to :user, ParkBench.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(like, attrs) do
    like
    |> cast(attrs, [:user_id, :likeable_type, :likeable_id])
    |> validate_required([:user_id, :likeable_type, :likeable_id])
    |> validate_inclusion(:likeable_type, @valid_likeable_types)
    |> unique_constraint([:user_id, :likeable_type, :likeable_id],
      name: :likes_user_id_likeable_type_likeable_id_index
    )
    |> foreign_key_constraint(:user_id)
  end
end
