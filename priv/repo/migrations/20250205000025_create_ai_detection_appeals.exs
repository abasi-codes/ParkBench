defmodule ParkBench.Repo.Migrations.CreateAiDetectionAppeals do
  use Ecto.Migration

  def change do
    create table(:ai_detection_appeals, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")

      add :detection_result_id,
          references(:ai_detection_results, type: :uuid, on_delete: :delete_all), null: false

      add :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
      add :explanation, :text, null: false
      add :tools_used, :text
      add :status, :string, default: "pending"
      add :reviewed_by_id, references(:users, type: :uuid)
      add :reviewed_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:ai_detection_appeals, [:detection_result_id])
    create index(:ai_detection_appeals, [:user_id])
    create index(:ai_detection_appeals, [:status])
  end
end
