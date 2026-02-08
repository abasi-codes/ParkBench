defmodule ParkBench.Repo.Migrations.CreateWellnessEmbeds do
  use Ecto.Migration

  def change do
    create table(:wellness_embeds, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")

      add :wall_post_id, references(:wall_posts, type: :uuid, on_delete: :delete_all), null: false

      add :steps, :integer
      add :heart_rate_bpm, :integer
      add :distance_km, :float
      add :calories, :integer
      add :sleep_hours, :float
      add :recorded_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:wellness_embeds, [:wall_post_id])
  end
end
