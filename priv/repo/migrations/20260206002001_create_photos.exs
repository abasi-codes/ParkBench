defmodule Sunporch.Repo.Migrations.CreatePhotos do
  use Ecto.Migration

  def change do
    create table(:photos, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :album_id, references(:photo_albums, type: :binary_id, on_delete: :delete_all), null: false
      add :original_url, :string, null: false
      add :thumb_200_url, :string
      add :thumb_50_url, :string
      add :caption, :string, size: 500
      add :position, :integer, default: 0
      add :ai_detection_status, :string, default: "pending"
      add :ai_detection_score, :float
      add :content_hash, :string
      add :deleted_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:photos, [:album_id])
    create index(:photos, [:user_id])
    create index(:photos, [:album_id, :position])
  end
end
