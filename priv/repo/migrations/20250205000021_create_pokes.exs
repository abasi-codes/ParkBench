defmodule ParkBench.Repo.Migrations.CreatePokes do
  use Ecto.Migration

  def change do
    create table(:pokes, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :poker_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
      add :pokee_id, references(:users, type: :uuid, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:pokes, [:poker_id, :pokee_id])
    create index(:pokes, [:pokee_id])
  end
end
