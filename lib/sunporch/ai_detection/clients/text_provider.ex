defmodule Sunporch.AIDetection.Clients.TextProvider do
  @moduledoc "Behaviour for text AI detection providers"
  @callback detect(text :: String.t()) :: {:ok, %{score: float(), raw_response: map()}} | {:error, any()}
end
