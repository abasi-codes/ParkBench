defmodule Sunporch.Repo.Migrations.CreateStatusUpdates do
  use Ecto.Migration

  def change do
    create table(:status_updates, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
      add :body, :string, size: 160, null: false
      add :ai_detection_status, :string, default: "approved"
      add :ai_detection_score, :float
      add :content_hash, :string

      timestamps(type: :utc_datetime)
    end

    create index(:status_updates, [:user_id])
  end
end
