defmodule Sunporch.Repo.Migrations.CreateMessages do
  use Ecto.Migration

  def change do
    create table(:messages, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :thread_id, references(:message_threads, type: :uuid, on_delete: :delete_all), null: false
      add :sender_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
      add :encrypted_body, :binary, null: false
      add :ai_detection_status, :string, default: "pending"
      add :ai_detection_score, :float
      add :content_hash, :string

      timestamps(type: :utc_datetime)
    end

    create index(:messages, [:thread_id])
    create index(:messages, [:sender_id])
  end
end
