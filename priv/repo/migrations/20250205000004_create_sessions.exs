defmodule ParkBench.Repo.Migrations.CreateSessions do
  use Ecto.Migration

  def change do
    create table(:sessions, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
      add :token_hash, :string, null: false
      add :ip_address, :string
      add :user_agent, :string, size: 500
      add :last_active_at, :utc_datetime
      add :expires_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:sessions, [:user_id])
    create unique_index(:sessions, [:token_hash])
  end
end
