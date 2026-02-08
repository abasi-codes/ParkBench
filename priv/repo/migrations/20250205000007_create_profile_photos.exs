defmodule Sunporch.Repo.Migrations.CreateProfilePhotos do
  use Ecto.Migration

  def change do
    create table(:profile_photos, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
      add :original_url, :string, null: false
      add :thumb_200_url, :string
      add :thumb_50_url, :string
      add :is_current, :boolean, default: false
      add :ai_detection_status, :string, default: "pending"
      add :ai_detection_score, :float
      add :content_hash, :string

      timestamps(type: :utc_datetime)
    end

    create index(:profile_photos, [:user_id])

    create unique_index(:profile_photos, [:user_id],
      where: "is_current = true",
      name: :profile_photos_user_id_current_unique
    )
  end
end
