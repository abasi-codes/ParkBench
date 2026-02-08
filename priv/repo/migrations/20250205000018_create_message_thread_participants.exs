defmodule Sunporch.Repo.Migrations.CreateMessageThreadParticipants do
  use Ecto.Migration

  def change do
    create table(:message_thread_participants, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :thread_id, references(:message_threads, type: :uuid, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
      add :last_read_at, :utc_datetime
      add :deleted_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:message_thread_participants, [:thread_id, :user_id])
    create index(:message_thread_participants, [:user_id])
  end
end
