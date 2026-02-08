defmodule Sunporch.Repo.Migrations.CreateNotifications do
  use Ecto.Migration

  def change do
    create table(:notifications, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
      add :actor_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
      add :type, :string, null: false
      add :target_type, :string
      add :target_id, :uuid
      add :read_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:notifications, [:user_id, :read_at])
    create index(:notifications, [:user_id, :inserted_at], name: :notifications_user_id_inserted_at_desc)
  end
end
