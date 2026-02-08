defmodule ParkBench.Repo.Migrations.AddSharedPostIdToMessages do
  use Ecto.Migration

  def change do
    alter table(:messages) do
      add :shared_post_id, references(:wall_posts, type: :uuid, on_delete: :nilify_all)
    end

    create index(:messages, [:shared_post_id], where: "shared_post_id IS NOT NULL")
  end
end
