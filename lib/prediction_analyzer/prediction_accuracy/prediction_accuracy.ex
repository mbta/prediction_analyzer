defmodule PredictionAnalyzer.PredictionAccuracy.PredictionAccuracy do
  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query, only: [from: 2]
  import PredictionAnalyzer.Filters

  schema "prediction_accuracy" do
    field(:environment, :string)
    field(:service_date, :date)
    field(:hour_of_day, :integer)
    field(:stop_id, :string)
    field(:route_id, :string)
    field(:direction_id, :integer)
    field(:arrival_departure, :string)
    field(:bin, :string)
    field(:num_predictions, :integer)
    field(:num_accurate_predictions, :integer)
  end

  def new_insert_changeset(params \\ %{}) do
    all_fields = [
      :service_date,
      :hour_of_day,
      :stop_id,
      :route_id,
      :direction_id,
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

  @spec filter(map()) :: {Ecto.Query.t(), nil | String.t()}
  def filter(params) do
    q = from(acc in __MODULE__, [])

    with {:ok, q} <- filter_by_route(q, params["route_ids"]),
         {:ok, q} <- filter_by_stop(q, params["stop_id"]),
         {:ok, q} <- filter_by_direction(q, params["direction_id"]),
         {:ok, q} <- filter_by_arrival_departure(q, params["arrival_departure"]),
         {:ok, q} <- filter_by_bin(q, params["bin"]),
         {:ok, q} <- filter_by_mode(q, params["mode"]),
         {:ok, q} <-
           filter_by_timeframe(
             q,
             params["chart_range"],
             params["service_date"],
             params["date_start"],
             params["date_end"]
           ) do
      {q, nil}
    else
      {:error, msg} -> {from(acc in q, where: false), msg}
    end
  end
end
