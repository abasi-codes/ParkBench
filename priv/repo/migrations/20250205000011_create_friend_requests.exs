defmodule ParkBench.Repo.Migrations.CreateFriendRequests do
  use Ecto.Migration

  def change do
    create table(:friend_requests, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :sender_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
      add :receiver_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
      add :status, :string, default: "pending"

      timestamps(type: :utc_datetime)
    end

    create unique_index(:friend_requests, [:sender_id, :receiver_id],
             where: "status = 'pending'",
             name: :friend_requests_sender_receiver_pending_unique
           )

    create index(:friend_requests, [:receiver_id])
    create index(:friend_requests, [:sender_id])
  end
end
