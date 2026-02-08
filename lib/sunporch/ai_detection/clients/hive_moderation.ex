defmodule Sunporch.AIDetection.Clients.HiveModeration do
  @moduledoc "Hive Moderation API client for image AI detection"
  @behaviour Sunporch.AIDetection.Clients.ImageProvider

  @base_url "https://api.thehive.ai/api/v2/task/sync"
  @timeout 10_000

  @impl true
  def detect(image_url) do
    api_key = Application.get_env(:sunporch, :ai_detection)[:hive_api_key]

    case Req.post(@base_url,
      json: %{url: image_url},
      headers: [{"authorization", "token #{api_key}"}, {"content-type", "application/json"}],
      receive_timeout: @timeout
    ) do
      {:ok, %{status: 200, body: body}} ->
        score = extract_ai_score(body)
        {:ok, %{score: score, raw_response: body}}

      {:ok, %{status: status, body: body}} ->
        {:error, %{status: status, body: body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp extract_ai_score(body) do
    body
    |> get_in(["status", Access.filter(&(&1["response"]["output"])), "response", "output"])
    |> case do
      nil -> 0.0
      outputs when is_list(outputs) ->
        outputs
        |> List.flatten()
        |> Enum.find_value(0.0, fn
          %{"classes" => classes} ->
            Enum.find_value(classes, 0.0, fn
              %{"class" => "ai_generated", "score" => score} -> score
              _ -> nil
            end)
          _ -> nil
        end)
    end
  rescue
    _ -> 0.0
  end
end
