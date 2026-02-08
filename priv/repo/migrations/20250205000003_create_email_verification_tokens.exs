defmodule Sunporch.Repo.Migrations.CreateEmailVerificationTokens do
  use Ecto.Migration

  def change do
    create table(:email_verification_tokens, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
      add :token, :string, null: false
      add :expires_at, :utc_datetime, null: false
      add :used_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:email_verification_tokens, [:token])
    create index(:email_verification_tokens, [:user_id])
  end
end
