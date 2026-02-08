defmodule Sunporch.Workers.SessionPruneWorker do
  @moduledoc "Cron worker: removes expired sessions every 15 minutes"
  use Oban.Worker, queue: :cleanup

  import Ecto.Query
  alias Sunporch.Repo
  alias Sunporch.Accounts.Session

  @impl Oban.Worker
  def perform(_job) do
    {count, _} =
      from(s in Session, where: s.expires_at < ^DateTime.utc_now())
      |> Repo.delete_all()

    if count > 0 do
      require Logger
      Logger.info("Pruned #{count} expired sessions")
    end

    :ok
  end
end
