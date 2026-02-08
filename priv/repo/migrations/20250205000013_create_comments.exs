defmodule Sunporch.Repo.Migrations.CreateComments do
  use Ecto.Migration

  def change do
    create table(:comments, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :author_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
      add :commentable_type, :string, null: false
      add :commentable_id, :uuid, null: false
      add :body, :text, null: false
      add :ai_detection_status, :string, default: "pending"
      add :ai_detection_score, :float
      add :content_hash, :string
      add :deleted_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:comments, [:commentable_type, :commentable_id])
    create index(:comments, [:author_id])

    create index(:comments, [:id],
      where: "deleted_at IS NULL",
      name: :comments_not_deleted
    )
  end
end
