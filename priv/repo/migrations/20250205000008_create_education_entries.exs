defmodule ParkBench.Repo.Migrations.CreateEducationEntries do
  use Ecto.Migration

  def change do
    create table(:education_entries, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
      add :school_name, :string, size: 300, null: false
      add :degree, :string, size: 200
      add :field_of_study, :string, size: 200
      add :start_year, :integer
      add :end_year, :integer
      add :description, :text

      timestamps(type: :utc_datetime)
    end

    create index(:education_entries, [:user_id])
  end
end
