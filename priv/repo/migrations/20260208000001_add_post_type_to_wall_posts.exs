defmodule ParkBench.Repo.Migrations.AddPostTypeToWallPosts do
  use Ecto.Migration

  def change do
    alter table(:wall_posts) do
      add :post_type, :string, null: false, default: "story"
      add :mood, :string
    end

    create index(:wall_posts, [:post_type])
    create index(:wall_posts, [:author_id, :post_type])
  end
end
