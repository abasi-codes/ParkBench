defmodule ParkBench.Workers.UnverifiedAccountPurgeWorker do
  @moduledoc "Cron worker: purges unverified accounts older than 72 hours"
  use Oban.Worker, queue: :cleanup

  import Ecto.Query
  alias ParkBench.Repo
  alias ParkBench.Accounts.User

  @impl Oban.Worker
  def perform(_job) do
    cutoff = DateTime.add(DateTime.utc_now(), -72 * 3600, :second)

    {count, _} =
      from(u in User,
        where: is_nil(u.email_verified_at) and u.inserted_at < ^cutoff
      )
      |> Repo.delete_all()

    if count > 0 do
      require Logger
      Logger.info("Purged #{count} unverified accounts")
    end

    :ok
  end
end
