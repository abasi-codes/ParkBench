defmodule ParkBench.Repo.Migrations.CreateLikes do
  use Ecto.Migration

  def change do
    create table(:likes, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
      add :likeable_type, :string, null: false
      add :likeable_id, :uuid, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:likes, [:user_id, :likeable_type, :likeable_id])
    create index(:likes, [:likeable_type, :likeable_id])
  end
end
