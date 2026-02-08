defmodule ParkBench.Timeline.KidEmbed do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "kid_embeds" do
    field :milestone_text, :string
    field :quote_text, :string
    field :quote_attribution, :string

    belongs_to :wall_post, ParkBench.Timeline.WallPost
    belongs_to :kid, ParkBench.Timeline.Kid

    timestamps(type: :utc_datetime)
  end

  def changeset(kid_embed, attrs) do
    kid_embed
    |> cast(attrs, [:wall_post_id, :kid_id, :milestone_text, :quote_text, :quote_attribution])
    |> validate_required([:wall_post_id, :kid_id])
    |> validate_length(:milestone_text, max: 500)
    |> validate_length(:quote_text, max: 1000)
    |> validate_length(:quote_attribution, max: 255)
    |> foreign_key_constraint(:wall_post_id)
    |> foreign_key_constraint(:kid_id)
  end
end
