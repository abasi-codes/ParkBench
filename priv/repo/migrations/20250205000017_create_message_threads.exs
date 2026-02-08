defmodule ParkBench.Repo.Migrations.CreateMessageThreads do
  use Ecto.Migration

  def change do
    create table(:message_threads, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :subject, :string, size: 500
      add :last_message_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end
  end
end
