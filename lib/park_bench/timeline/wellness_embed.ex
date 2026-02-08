defmodule ParkBench.Timeline.WellnessEmbed do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "wellness_embeds" do
    field :steps, :integer
    field :heart_rate_bpm, :integer
    field :distance_km, :float
    field :calories, :integer
    field :sleep_hours, :float
    field :recorded_at, :utc_datetime

    belongs_to :wall_post, ParkBench.Timeline.WallPost

    timestamps(type: :utc_datetime)
  end

  def changeset(wellness_embed, attrs) do
    wellness_embed
    |> cast(attrs, [
      :wall_post_id,
      :steps,
      :heart_rate_bpm,
      :distance_km,
      :calories,
      :sleep_hours,
      :recorded_at
    ])
    |> validate_required([:wall_post_id])
    |> validate_number(:steps, greater_than_or_equal_to: 0, less_than_or_equal_to: 200_000)
    |> validate_number(:heart_rate_bpm, greater_than_or_equal_to: 30, less_than_or_equal_to: 250)
    |> validate_number(:distance_km, greater_than_or_equal_to: 0, less_than_or_equal_to: 500)
    |> validate_number(:calories, greater_than_or_equal_to: 0, less_than_or_equal_to: 50_000)
    |> validate_number(:sleep_hours, greater_than_or_equal_to: 0, less_than_or_equal_to: 24)
    |> unique_constraint(:wall_post_id)
    |> foreign_key_constraint(:wall_post_id)
  end
end
