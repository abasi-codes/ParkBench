defmodule ParkBench.Repo.Migrations.AddBenchStreakToUserProfiles do
  use Ecto.Migration

  def change do
    alter table(:user_profiles) do
      add :bench_streak, :integer, null: false, default: 0
      add :last_active_date, :date
    end
  end
end
