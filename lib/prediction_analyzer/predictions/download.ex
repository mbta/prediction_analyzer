defmodule PredictionAnalyzer.Predictions.Download do
  use GenServer

  require Logger
  alias PredictionAnalyzer.Predictions.Prediction

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, opts)
  end

  def init(args) do
    schedule_prod_fetch(self(), 1_000)
    schedule_dev_green_fetch(self(), 11_000)
    schedule_commuter_rail_fetch(self(), 21_000)
    {:ok, args}
  end

  def get_subway_predictions(env) do
    {aws_predictions_url, http_fetcher} = get_vars(env)
    Logger.info("Downloading subway predictions from #{aws_predictions_url}")
    %{body: body} = http_fetcher.get!(aws_predictions_url)

    body
    |> Jason.decode!()
    |> store_subway_predictions(env)
  end

  @spec get_commuter_rail_predictions(:prod | :dev_green) :: no_return
  def get_commuter_rail_predictions(env) do
    {_, http_fetcher} = get_vars(env)
    api_base_url = Application.get_env(:prediction_analyzer, :api_base_url)
    url_path = "predictions"

    api_key = Application.get_env(:prediction_analyzer, :api_v3_key)
    headers = if api_key, do: [{"x-api-key", api_key}], else: []

    params = %{
      "filter[route]" =>
        :commuter_rail |> PredictionAnalyzer.Utilities.routes_for_mode() |> Enum.join(","),
      "include" => "vehicle"
    }

    %{body: body, headers: headers} =
      http_fetcher.get!(api_base_url <> url_path, headers, params: params)

    last_modified = headers |> Enum.into(%{}) |> Map.get("last-modified")

    body
    |> Jason.decode!()
    |> store_commuter_rail_predictions(last_modified, env)
  end

  defp get_vars(:prod) do
    prod_aws_predictions_url = Application.get_env(:prediction_analyzer, :aws_predictions_url)
    http_fetcher = Application.get_env(:prediction_analyzer, :http_fetcher)
    {prod_aws_predictions_url, http_fetcher}
  end

  defp get_vars(:dev_green) do
    dev_green_aws_predictions_url =
      Application.get_env(:prediction_analyzer, :dev_green_aws_predictions_url)

    http_fetcher = Application.get_env(:prediction_analyzer, :http_fetcher)
    {dev_green_aws_predictions_url, http_fetcher}
  end

  defp schedule_prod_fetch(pid, ms) do
    Process.send_after(pid, :get_prod_predictions, ms)
  end

  defp schedule_dev_green_fetch(pid, ms) do
    Process.send_after(pid, :get_dev_green_predictions, ms)
  end

  defp schedule_commuter_rail_fetch(pid, ms) do
    Process.send_after(pid, :get_commuter_rail_predictions, ms)
  end

  def handle_info(:get_prod_predictions, _state) do
    schedule_prod_fetch(self(), 60_000)
    predictions = get_subway_predictions(:prod)
    {:noreply, predictions}
  end

  def handle_info(:get_dev_green_predictions, _state) do
    schedule_dev_green_fetch(self(), 60_000)
    predictions = get_subway_predictions(:dev_green)
    {:noreply, predictions}
  end

  def handle_info(:get_commuter_rail_predictions, _state) do
    schedule_commuter_rail_fetch(self(), 60_000)
    predictions = get_commuter_rail_predictions(:prod)
    {:noreply, predictions}
  end

  @spec store_subway_predictions(map(), :dev_green | :prod) ::
          {integer(), nil | [term()]} | no_return()
  defp store_subway_predictions(
         %{"entity" => entities, "header" => %{"timestamp" => timestamp}},
         env
       ) do
    predictions =
      Enum.flat_map(entities, fn prediction ->
        trip_prediction = %{
          file_timestamp: timestamp,
          environment:
            case env do
              :prod -> "prod"
              :dev_green -> "dev-green"
            end,
          trip_id: prediction["trip_update"]["trip"]["trip_id"],
          vehicle_id: prediction["trip_update"]["vehicle"]["id"],
          route_id: prediction["trip_update"]["trip"]["route_id"],
          direction_id: prediction["trip_update"]["trip"]["direction_id"],
          is_deleted: prediction["is_deleted"]
        }

        if prediction["trip_update"]["stop_time_update"] != nil do
          Enum.map(prediction["trip_update"]["stop_time_update"], fn update ->
            Map.merge(trip_prediction, %{
              arrival_time: update["arrival"]["time"],
              departure_time: update["departure"]["time"],
              boarding_status: update["boarding_status"],
              schedule_relationship: update["schedule_relationship"],
              stop_id: PredictionAnalyzer.Utilities.generic_stop_id(update["stop_id"]),
              stop_sequence: update["stop_sequence"],
              stops_away: update["stops_away"]
            })
          end)
        end
      end)

    {_, _} = PredictionAnalyzer.Repo.insert_all(Prediction, predictions)
  end

  defp store_subway_predictions(_, _) do
    nil
  end

  defp store_commuter_rail_predictions(%{"data" => data} = response, last_modified, env) do
    {:ok, timestamp} = last_modified |> Timex.parse("{RFC1123}")
    timestamp = DateTime.to_unix(timestamp)

    predictions =
      Enum.map(data, fn prediction ->
        arrival_time_unix =
          case prediction["attributes"]["arrival_time"] do
            nil ->
              nil

            arrival_time ->
              {:ok, arrival_dt, _offset} = DateTime.from_iso8601(arrival_time)
              DateTime.to_unix(arrival_dt)
          end

        departure_time_unix =
          case prediction["attributes"]["departure_time"] do
            nil ->
              nil

            departure_time ->
              {:ok, departure_dt, _offset} = DateTime.from_iso8601(departure_time)
              DateTime.to_unix(departure_dt)
          end

        %{
          environment: "prod",
          file_timestamp: timestamp,
          vehicle_id: prediction["relationships"]["vehicle"]["data"]["id"] || "CR-na",
          trip_id: prediction["relationships"]["trip"]["data"]["id"],
          route_id: prediction["relationships"]["route"]["data"]["id"],
          direction_id: prediction["attributes"]["direction_id"],
          # is_deleted: prediction["is_deleted"],
          arrival_time: arrival_time_unix,
          departure_time: departure_time_unix,
          boarding_status: prediction["attributes"]["status"],
          schedule_relationship: prediction["attributes"]["schedule_relationship"],
          stop_id: prediction["relationships"]["stop"]["data"]["id"],
          stop_sequence: prediction["attributes"]["stop_sequence"]
        }
      end)

    {_, _} = PredictionAnalyzer.Repo.insert_all(Prediction, predictions)
  end

  defp store_commuter_rail_predictions(_, _) do
    nil
  end
end
