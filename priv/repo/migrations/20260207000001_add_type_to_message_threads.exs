defmodule ParkBench.Repo.Migrations.AddTypeToMessageThreads do
  use Ecto.Migration

  def change do
    alter table(:message_threads) do
      add :type, :string, null: false, default: "inbox"
    end

    create index(:message_threads, [:type])
  end
end
