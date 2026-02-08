defmodule ParkBench.Repo do
  use Ecto.Repo,
    otp_app: :park_bench,
    adapter: Ecto.Adapters.Postgres
end
