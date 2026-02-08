defmodule ParkBenchWeb.ChannelCase do
  @moduledoc """
  This module defines the test case to be used by
  channel tests.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # Import conveniences for testing with channels
      import Phoenix.ChannelTest
      import ParkBenchWeb.ChannelCase
      import ParkBench.Factory

      # The default endpoint for testing
      @endpoint ParkBenchWeb.Endpoint
    end
  end

  setup tags do
    ParkBench.DataCase.setup_sandbox(tags)
    :ok
  end
end
