defmodule ParkBench.Repo.Migrations.CreatePetEmbeds do
  use Ecto.Migration

  def change do
    create table(:pet_embeds, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")

      add :wall_post_id, references(:wall_posts, type: :uuid, on_delete: :delete_all), null: false

      add :pet_id, references(:pets, type: :uuid, on_delete: :delete_all), null: false
      add :activity_note, :string

      timestamps(type: :utc_datetime)
    end

    create index(:pet_embeds, [:wall_post_id])
    create index(:pet_embeds, [:pet_id])
  end
end
