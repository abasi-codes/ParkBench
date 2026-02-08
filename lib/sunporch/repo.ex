defmodule Sunporch.Repo do
  use Ecto.Repo,
    otp_app: :sunporch,
    adapter: Ecto.Adapters.Postgres
end
