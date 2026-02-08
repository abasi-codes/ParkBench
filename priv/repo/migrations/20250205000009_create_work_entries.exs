defmodule ParkBench.Repo.Migrations.CreateWorkEntries do
  use Ecto.Migration

  def change do
    create table(:work_entries, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
      add :company_name, :string, size: 300, null: false
      add :position, :string, size: 200
      add :city, :string, size: 200
      add :start_date, :date
      add :end_date, :date
      add :description, :text
      add :is_current, :boolean, default: false

      timestamps(type: :utc_datetime)
    end

    create index(:work_entries, [:user_id])
  end
end
