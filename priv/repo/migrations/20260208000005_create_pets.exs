defmodule ParkBench.Repo.Migrations.CreatePets do
  use Ecto.Migration

  def change do
    create table(:pets, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :species, :string, null: false
      add :breed, :string
      add :age_years, :integer
      add :mood, :string
      add :emoji, :string, default: "\u{1F43E}"
      add :photo_url, :string
      add :deleted_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:pets, [:user_id])
  end
end
