defmodule SunporchWeb.Admin.AIThresholdsLive do
  use SunporchWeb, :live_view

  alias Sunporch.AIDetection

  @impl true
  def mount(_params, _session, socket) do
    thresholds = AIDetection.get_thresholds()

    {:ok,
     socket
     |> assign(:page_title, "AI Detection Thresholds")
     |> assign(:thresholds, thresholds)}
  end

  @impl true
  def handle_event("update_thresholds", params, socket) do
    attrs = %{
      text_soft_reject: parse_float(params["text_soft_reject"]),
      text_hard_reject: parse_float(params["text_hard_reject"]),
      image_soft_reject: parse_float(params["image_soft_reject"]),
      image_hard_reject: parse_float(params["image_hard_reject"])
    }

    case AIDetection.update_thresholds(attrs) do
      {:ok, thresholds} ->
        {:noreply, assign(socket, :thresholds, thresholds) |> put_flash(:info, "Thresholds updated.")}
      _ ->
        {:noreply, put_flash(socket, :error, "Could not update thresholds.")}
    end
  end

  defp parse_float(val) when is_binary(val), do: String.to_float(val)
  defp parse_float(val) when is_float(val), do: val
  defp parse_float(_), do: 0.0

  @impl true
  def render(assigns) do
    ~H"""
    <div class="admin-page">
      <h1>AI Detection Thresholds</h1>
      <p>Adjust the score thresholds for AI content detection.</p>

      <form phx-submit="update_thresholds" class="thresholds-form">
        <h2>Text Detection (GPTZero)</h2>
        <div class="form-group">
          <label>Soft Reject Threshold (current: {@thresholds.text_soft_reject})</label>
          <input type="number" name="text_soft_reject" value={@thresholds.text_soft_reject} step="0.01" min="0" max="1" />
        </div>
        <div class="form-group">
          <label>Hard Reject Threshold (current: {@thresholds.text_hard_reject})</label>
          <input type="number" name="text_hard_reject" value={@thresholds.text_hard_reject} step="0.01" min="0" max="1" />
        </div>

        <h2>Image Detection (Hive)</h2>
        <div class="form-group">
          <label>Soft Reject Threshold (current: {@thresholds.image_soft_reject})</label>
          <input type="number" name="image_soft_reject" value={@thresholds.image_soft_reject} step="0.01" min="0" max="1" />
        </div>
        <div class="form-group">
          <label>Hard Reject Threshold (current: {@thresholds.image_hard_reject})</label>
          <input type="number" name="image_hard_reject" value={@thresholds.image_hard_reject} step="0.01" min="0" max="1" />
        </div>

        <button type="submit" class="btn btn-blue">Save Thresholds</button>
      </form>
    </div>
    """
  end
end
