defmodule PredictionAnalyzerWeb.AccuracyView do
  use PredictionAnalyzerWeb, :view
  alias PredictionAnalyzer.PredictionAccuracy.PredictionAccuracy

  def accuracy_percentage(num_accurate, num_predictions)
      when is_integer(num_accurate) and is_integer(num_predictions) and num_predictions != 0 do
    Float.round(100 * num_accurate / num_predictions, 2)
  end

  def accuracy_percentage(_, _) do
    0
  end

  def service_dates(now \\ Timex.local()) do
    0..7
    |> Enum.map(fn n ->
      now
      |> Timex.shift(days: -1 * n)
      |> DateTime.to_date()
      |> Date.to_string()
    end)
  end
end
