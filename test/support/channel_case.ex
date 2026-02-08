defmodule SunporchWeb.ChannelCase do
  @moduledoc """
  This module defines the test case to be used by
  channel tests.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # Import conveniences for testing with channels
      import Phoenix.ChannelTest
      import SunporchWeb.ChannelCase
      import Sunporch.Factory

      # The default endpoint for testing
      @endpoint SunporchWeb.Endpoint
    end
  end

  setup tags do
    Sunporch.DataCase.setup_sandbox(tags)
    :ok
  end
end
