defmodule Sunporch.Repo.Migrations.CreatePrivacySettings do
  use Ecto.Migration

  def change do
    create table(:privacy_settings, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
      add :profile_visibility, :string, default: "everyone"
      add :bio_visibility, :string, default: "friends"
      add :interests_visibility, :string, default: "friends"
      add :education_visibility, :string, default: "friends"
      add :work_visibility, :string, default: "friends"
      add :birthday_visibility, :string, default: "friends"
      add :hometown_visibility, :string, default: "friends"
      add :current_city_visibility, :string, default: "friends"
      add :phone_visibility, :string, default: "only_me"
      add :email_visibility, :string, default: "only_me"
      add :relationship_visibility, :string, default: "friends"
      add :wall_posting, :string, default: "friends"
      add :friend_list_visibility, :string, default: "friends"
      add :search_visible, :boolean, default: true

      timestamps(type: :utc_datetime)
    end

    create unique_index(:privacy_settings, [:user_id])
  end
end
