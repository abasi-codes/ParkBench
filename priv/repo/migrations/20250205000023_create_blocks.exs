defmodule Sunporch.Repo.Migrations.CreateBlocks do
  use Ecto.Migration

  def change do
    create table(:blocks, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :blocker_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
      add :blocked_id, references(:users, type: :uuid, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:blocks, [:blocker_id, :blocked_id])
    create index(:blocks, [:blocked_id])
  end
end
