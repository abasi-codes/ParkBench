defmodule Sunporch.Repo.Migrations.CreateAiDetectionResults do
  use Ecto.Migration

  def change do
    create table(:ai_detection_results, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
      add :content_type, :string, null: false
      add :content_id, :uuid, null: false
      add :provider, :string, null: false
      add :score, :float, null: false
      add :raw_response, :map
      add :status, :string, null: false
      add :content_hash, :string

      timestamps(type: :utc_datetime)
    end

    create index(:ai_detection_results, [:content_type, :content_id])
    create index(:ai_detection_results, [:user_id])
    create index(:ai_detection_results, [:content_hash])

    create index(:ai_detection_results, [:id],
      where: "status = 'needs_review'",
      name: :ai_detection_results_needs_review
    )
  end
end
