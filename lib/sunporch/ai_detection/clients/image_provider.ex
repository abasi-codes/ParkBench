defmodule Sunporch.AIDetection.Clients.ImageProvider do
  @moduledoc "Behaviour for image AI detection providers"
  @callback detect(image_url :: String.t()) :: {:ok, %{score: float(), raw_response: map()}} | {:error, any()}
end
