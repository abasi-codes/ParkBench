defmodule Sunporch.Repo.Migrations.AddCoverPhotoUrlToProfiles do
  use Ecto.Migration

  def change do
    alter table(:user_profiles) do
      add :cover_photo_url, :string
    end
  end
end
