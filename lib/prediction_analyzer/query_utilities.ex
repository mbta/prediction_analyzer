defmodule PredictionAnalyzer.QueryUtilities do
  defmacro aggregate_mean_error(mean_error, num_predictions) do
    quote do
      fragment(
        "coalesce(sum(? * ?) / sum(?), 0)",
        unquote(mean_error),
        unquote(num_predictions),
        unquote(num_predictions)
      )
    end
  end

  defmacro aggregate_rmse(rmse, num_predictions) do
    quote do
      fragment(
        "sqrt(coalesce(sum(?^2 * ?) / sum(?), 0))",
        unquote(rmse),
        unquote(num_predictions),
        unquote(num_predictions)
      )
    end
  end

  defmacro resolution_bucket(minute_of_hour, timeframe_resolution) do
    quote do
      fragment(
        "(? / ?) * ? AS resolution_bucket",
        unquote(minute_of_hour),
        unquote(timeframe_resolution),
        unquote(timeframe_resolution)
      )
    end
  end
end
