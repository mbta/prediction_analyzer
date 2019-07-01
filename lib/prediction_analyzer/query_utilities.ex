defmodule PredictionAnalyzer.QueryUtilities do
  defmacro aggregate_mean_error(mean_error, num_predictions) do
    quote do
      fragment(
        "sum(? * ?) / sum(?)",
        unquote(mean_error),
        unquote(num_predictions),
        unquote(num_predictions)
      )
    end
  end

  defmacro aggregate_rmse(rmse, num_predictions) do
    quote do
      fragment(
        "sqrt(sum(?^2 * ?) / sum(?))",
        unquote(rmse),
        unquote(num_predictions),
        unquote(num_predictions)
      )
    end
  end
end
