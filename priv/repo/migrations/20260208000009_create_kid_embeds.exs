defmodule ParkBench.Repo.Migrations.CreateKidEmbeds do
  use Ecto.Migration

  def change do
    create table(:kid_embeds, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")

      add :wall_post_id, references(:wall_posts, type: :uuid, on_delete: :delete_all), null: false

      add :kid_id, references(:kids, type: :uuid, on_delete: :delete_all), null: false
      add :milestone_text, :string
      add :quote_text, :string
      add :quote_attribution, :string

      timestamps(type: :utc_datetime)
    end

    create index(:kid_embeds, [:wall_post_id])
    create index(:kid_embeds, [:kid_id])
  end
end
