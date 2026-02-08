defmodule ParkBench.Weather do
  @moduledoc "Weather data for sidebar widget. Returns static data; can be backed by API later."

  def current(_user \\ nil) do
    %{
      temperature: 72,
      condition: "Partly Cloudy",
      icon: "partly_cloudy",
      sunset: "6:42 PM",
      breeze: "Gentle",
      air: "Fresh"
    }
  end
end
