defmodule ParkBench.Repo.Migrations.AddPhotoUrlToWallPosts do
  use Ecto.Migration

  def change do
    alter table(:wall_posts) do
      add :photo_url, :string
    end
  end
end
