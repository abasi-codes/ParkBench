defmodule ParkBench.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :email, :citext, null: false
      add :display_name, :string, size: 100, null: false
      add :hashed_password, :string, null: false
      add :slug, :string, null: false
      add :role, :string, default: "user"
      add :email_verified_at, :utc_datetime
      add :locked_at, :utc_datetime
      add :failed_login_attempts, :integer, default: 0
      add :last_failed_login_at, :utc_datetime
      add :ai_flagged, :boolean, default: false
      add :ai_leniency_boost, :float, default: 0.0
      add :onboarding_completed_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, [:email])
    create unique_index(:users, [:slug])
    create index(:users, [:role])
  end
end
