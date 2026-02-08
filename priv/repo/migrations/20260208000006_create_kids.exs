defmodule ParkBench.Repo.Migrations.CreateKids do
  use Ecto.Migration

  def change do
    create table(:kids, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :age_years, :integer
      add :emoji, :string, default: "\u{1F476}"
      add :current_activity, :string
      add :deleted_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:kids, [:user_id])
  end
end
