defmodule PredictionAnalyzer.PredictionAccuracy.MonthlyReport do
  use Ecto.Schema

  import Ecto.Query, only: [from: 2]

  schema "prediction_accuracy_monthly_summary" do
    field(:month, :date)
    field(:query, :string)
    field(:num_predictions, :integer)
    field(:num_accurate, :integer)
    field(:mean_error, :float)
    field(:rmse, :float)
  end

  @spec months() :: Ecto.Query.t()
  def months() do
    from acc in __MODULE__,
      distinct: true,
      select: acc.month,
      order_by: [desc: acc.month]
  end
end
