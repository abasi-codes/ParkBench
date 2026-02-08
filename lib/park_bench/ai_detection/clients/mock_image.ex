defmodule ParkBench.AIDetection.Clients.MockImage do
  @moduledoc "Mock image AI detection for testing"
  @behaviour ParkBench.AIDetection.Clients.ImageProvider

  @impl true
  def detect(_image_url) do
    {:ok, %{score: 0.1, raw_response: %{mock: true}}}
  end
end
