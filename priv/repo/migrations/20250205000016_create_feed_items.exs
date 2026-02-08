defmodule ParkBench.Repo.Migrations.CreateFeedItems do
  use Ecto.Migration

  def change do
    create table(:feed_items, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
      add :item_type, :string, null: false
      add :content_id, :uuid, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:feed_items, [:user_id])
    create index(:feed_items, [:inserted_at], name: :feed_items_inserted_at_desc)
  end
end
