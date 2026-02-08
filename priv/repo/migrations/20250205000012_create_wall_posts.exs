defmodule Sunporch.Repo.Migrations.CreateWallPosts do
  use Ecto.Migration

  def change do
    create table(:wall_posts, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :author_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
      add :wall_owner_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
      add :body, :text, null: false
      add :ai_detection_status, :string, default: "pending"
      add :ai_detection_score, :float
      add :content_hash, :string
      add :deleted_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:wall_posts, [:wall_owner_id])
    create index(:wall_posts, [:author_id])

    create index(:wall_posts, [:id],
      where: "deleted_at IS NULL",
      name: :wall_posts_not_deleted
    )
  end
end
