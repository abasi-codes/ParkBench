defmodule ParkBench.Repo.Migrations.CreateUserProfiles do
  use Ecto.Migration

  def change do
    create table(:user_profiles, primary_key: false) do
      add :user_id, references(:users, type: :uuid, on_delete: :delete_all), primary_key: true
      add :bio, :text
      add :interests, :text
      add :hometown, :string, size: 200
      add :current_city, :string, size: 200
      add :birthday, :date
      add :gender, :string, size: 50
      add :relationship_status, :string, size: 50
      add :political_views, :string, size: 200
      add :religious_views, :string, size: 200
      add :website, :string, size: 500
      add :phone, :string, size: 50

      timestamps(type: :utc_datetime)
    end
  end
end
