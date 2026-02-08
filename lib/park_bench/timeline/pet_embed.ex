defmodule ParkBench.Timeline.PetEmbed do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "pet_embeds" do
    field :activity_note, :string

    belongs_to :wall_post, ParkBench.Timeline.WallPost
    belongs_to :pet, ParkBench.Timeline.Pet

    timestamps(type: :utc_datetime)
  end

  def changeset(pet_embed, attrs) do
    pet_embed
    |> cast(attrs, [:wall_post_id, :pet_id, :activity_note])
    |> validate_required([:wall_post_id, :pet_id])
    |> validate_length(:activity_note, max: 500)
    |> foreign_key_constraint(:wall_post_id)
    |> foreign_key_constraint(:pet_id)
  end
end
