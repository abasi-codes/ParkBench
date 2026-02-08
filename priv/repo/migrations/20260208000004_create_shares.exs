defmodule ParkBench.Repo.Migrations.CreateShares do
  use Ecto.Migration

  def change do
    create table(:shares, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
      add :wall_post_id, references(:wall_posts, type: :uuid, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:shares, [:user_id, :wall_post_id])
    create index(:shares, [:wall_post_id])
  end
end
