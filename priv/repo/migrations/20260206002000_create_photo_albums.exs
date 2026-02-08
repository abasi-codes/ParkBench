defmodule ParkBench.Repo.Migrations.CreatePhotoAlbums do
  use Ecto.Migration

  def change do
    create table(:photo_albums, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :title, :string, null: false
      add :description, :text
      add :photo_count, :integer, default: 0
      add :cover_photo_id, :binary_id

      timestamps(type: :utc_datetime)
    end

    create index(:photo_albums, [:user_id])
    create index(:photo_albums, [:user_id, :inserted_at])
  end
end
