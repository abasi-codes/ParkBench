defmodule Sunporch.AIDetection.ThresholdServer do
  @moduledoc "GenServer that stores AI detection thresholds in ETS for fast reads"
  use GenServer

  @table :ai_thresholds
  @key :current

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def get_thresholds do
    case :ets.lookup(@table, @key) do
      [{@key, thresholds}] -> thresholds
      [] -> nil
    end
  rescue
    ArgumentError -> nil
  end

  def update_thresholds(attrs) do
    GenServer.call(__MODULE__, {:update, attrs})
  end

  @impl true
  def init(_opts) do
    table = :ets.new(@table, [:named_table, :set, :public, read_concurrency: true])

    defaults = %{
      text_soft_reject: Application.get_env(:sunporch, :ai_detection)[:text_soft_reject] || 0.65,
      text_hard_reject: Application.get_env(:sunporch, :ai_detection)[:text_hard_reject] || 0.85,
      image_soft_reject: Application.get_env(:sunporch, :ai_detection)[:image_soft_reject] || 0.70,
      image_hard_reject: Application.get_env(:sunporch, :ai_detection)[:image_hard_reject] || 0.90
    }

    :ets.insert(table, {@key, defaults})
    {:ok, %{table: table}}
  end

  @impl true
  def handle_call({:update, attrs}, _from, state) do
    current = case :ets.lookup(@table, @key) do
      [{@key, t}] -> t
      [] -> %{}
    end

    updated = Map.merge(current, normalize_attrs(attrs))
    :ets.insert(@table, {@key, updated})
    {:reply, {:ok, updated}, state}
  end

  defp normalize_attrs(attrs) do
    attrs
    |> Enum.map(fn
      {k, v} when is_binary(k) -> {String.to_existing_atom(k), ensure_float(v)}
      {k, v} when is_atom(k) -> {k, ensure_float(v)}
    end)
    |> Enum.filter(fn {k, _} -> k in [:text_soft_reject, :text_hard_reject, :image_soft_reject, :image_hard_reject] end)
    |> Map.new()
  end

  defp ensure_float(v) when is_float(v), do: v
  defp ensure_float(v) when is_integer(v), do: v / 1
  defp ensure_float(v) when is_binary(v), do: String.to_float(v)
end
