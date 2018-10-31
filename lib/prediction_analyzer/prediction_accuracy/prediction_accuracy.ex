defmodule PredictionAnalyzer.PredictionAccuracy.PredictionAccuracy do
  use Ecto.Schema
  import Ecto.Changeset

  schema "prediction_accuracy" do
    field(:service_date, :date)
    field(:hour_of_day, :integer)
    field(:stop_id, :string)
    field(:route_id, :string)
    field(:arrival_departure, :string)
    field(:bin, :string)
    field(:num_predictions, :integer)
    field(:num_accurate_predictions, :integer)
  end

  @doc """
  Defines the bins we consider for aggregate accuracy. Each bin has the
  window of predictions that it applies to (e.g. arriving within 3-6 minutes)
  and the tolerance in seconds for which a prediction is considered accurate.
  """
  @spec bins() :: map()
  def bins do
    %{
      "0-3 min" => {0, 180, -60, 60},
      "3-6 min" => {180, 360, -90, 120},
      "6-12 min" => {360, 720, -150, 210},
      "12-30 min" => {720, 1800, -240, 360}
    }
  end

  def new_insert_changeset(params \\ %{}) do
    all_fields = [
      :service_date,
      :hour_of_day,
      :stop_id,
      :route_id,
      :arrival_departure,
      :bin,
      :num_predictions,
      :num_accurate_predictions
    ]

    %__MODULE__{}
    |> cast(params, all_fields)
    |> validate_required(all_fields)
    |> validate_inclusion(:arrival_departure, ["arrival", "departure"])
    |> validate_inclusion(:bin, Map.keys(bins()))
  end
end
