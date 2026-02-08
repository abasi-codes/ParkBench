defmodule ParkBench.AIDetection.Clients.GPTZero do
  @moduledoc "GPTZero API client for text AI detection"
  @behaviour ParkBench.AIDetection.Clients.TextProvider

  @base_url "https://api.gptzero.me/v2/predict/text"
  @timeout 5_000

  @impl true
  def detect(text) do
    api_key = Application.get_env(:park_bench, :ai_detection)[:gptzero_api_key]

    case Req.post(@base_url,
           json: %{document: text},
           headers: [{"x-api-key", api_key}, {"content-type", "application/json"}],
           receive_timeout: @timeout
         ) do
      {:ok, %{status: 200, body: body}} ->
        score = get_in(body, ["documents", Access.at(0), "completely_generated_prob"]) || 0.0
        {:ok, %{score: score, raw_response: body}}

      {:ok, %{status: status, body: body}} ->
        {:error, %{status: status, body: body}}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
