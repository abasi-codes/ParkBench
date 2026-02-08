defmodule Sunporch.AIDetection.Clients.MockText do
  @moduledoc "Mock text AI detection for testing"
  @behaviour Sunporch.AIDetection.Clients.TextProvider

  @impl true
  def detect(_text) do
    {:ok, %{score: 0.1, raw_response: %{mock: true}}}
  end
end
