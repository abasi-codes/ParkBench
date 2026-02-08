defmodule ParkBenchWeb.Presence do
  use Phoenix.Presence, otp_app: :park_bench, pubsub_server: ParkBench.PubSub
end
