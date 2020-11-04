defmodule PredictionAnalyzer.Predictions.Download do
  use GenServer

  require Logger
  alias PredictionAnalyzer.{Filters, Predictions.Prediction}

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, opts)
  end

  def init(args \\ []) do
    initial_prod_fetch_ms = args[:initial_prod_fetch_ms] || 1_000
    initial_dev_green_fetch_ms = args[:initial_dev_green_fetch_ms] || 11_000
    initial_commuter_rail_fetch_ms = args[:initial_commuter_rail_fetch_ms] || 21_000

    schedule_prod_fetch(self(), initial_prod_fetch_ms)
    schedule_dev_green_fetch(self(), initial_dev_green_fetch_ms)
    schedule_commuter_rail_fetch(self(), initial_commuter_rail_fetch_ms)

    {:ok, %{}}
  end

  def get_subway_predictions(env) do
    {aws_predictions_url, http_fetcher} = get_vars(env)
    Logger.info("Downloading subway predictions from #{aws_predictions_url}")
    %{body: body} = http_fetcher.get!(aws_predictions_url)

    body
    |> Jason.decode!()
    |> store_subway_predictions(env)
  end

  @spec get_commuter_rail_predictions() :: {integer(), nil | [term()]} | no_return()
  def get_commuter_rail_predictions() do
    url_path = "predictions"

    params = %{
      "filter[route]" =>
        :commuter_rail |> PredictionAnalyzer.Utilities.routes_for_mode() |> Enum.join(","),
      "include" => "vehicle"
    }

    case PredictionAnalyzer.Utilities.APIv3.request(url_path, params: params) do
      {:ok, %{body: body, headers: headers}} ->
        last_modified = headers |> Enum.into(%{}) |> Map.get("last-modified")

        body
        |> Jason.decode!()
        |> store_commuter_rail_predictions(last_modified)

      {:error, e} ->
        Logger.warn("Could not download commuter rail predictions; received: #{inspect(e)}")
        %{}
    end
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
    predictions = get_commuter_rail_predictions()
    {:noreply, predictions}
  end

  def handle_info({:ssl_closed, _socket}, state) do
    {:noreply, state}
  end

  def handle_info(msg, state) do
    Logger.warn(
      "PredictionAnalyzer.Predictions.Download event=unexpected_message message=#{inspect(msg)}"
    )

    {:noreply, state}
  end

  @spec store_subway_predictions(map(), :dev_green | :prod) ::
          {integer(), nil | [term()]} | no_return()
  defp store_subway_predictions(
         %{"entity" => entities, "header" => %{"timestamp" => timestamp}},
         env
       ) do
    predictions =
      entities
      |> predictions_from_entites(timestamp, env)
      |> calculate_nth_at_stop()

    {_, _} = PredictionAnalyzer.Repo.insert_all(Prediction, predictions)
  end

  defp store_subway_predictions(_, _) do
    nil
  end

  @spec predictions_from_entites([map()], integer(), :prod | :dev_green) :: [map()]
  defp predictions_from_entites(entities, timestamp, env) do
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
        is_deleted: prediction["is_deleted"],
        nth_at_stop: nil
      }

      Enum.reduce(prediction["trip_update"]["stop_time_update"] || [], [], fn update, acc ->
        if is_nil(update["stops_away"]) ||
             (is_nil(get_in(update, ["arrival", "time"])) &&
                is_nil(get_in(update, ["departure", "time"]))) do
          acc
        else
          acc ++
            [
              Map.merge(trip_prediction, %{
                arrival_time: update["arrival"]["time"],
                departure_time: update["departure"]["time"],
                boarding_status: update["boarding_status"],
                kind: kind_from_stop_time_update(update),
                schedule_relationship: update["schedule_relationship"],
                stop_id: PredictionAnalyzer.Utilities.generic_stop_id(update["stop_id"]),
                stop_sequence: update["stop_sequence"],
                stops_away: update["stops_away"]
              })
            ]
        end
      end)
    end)
  end

  @spec calculate_nth_at_stop([map()]) :: [map()]
  defp calculate_nth_at_stop(predictions) do
    predictions
    |> Enum.group_by(& &1.stop_id)
    |> Enum.flat_map(fn {stop_id, predictions} ->
      if !is_nil(stop_id) do
        predictions
        |> Enum.sort_by(
          &{if(&1.stops_away == 0, do: 0, else: 1), &1.arrival_time || &1.departure_time}
        )
        |> Enum.with_index(1)
        |> Enum.map(fn {prediction, index} -> %{prediction | nth_at_stop: index} end)
      else
        predictions
      end
    end)
  end

  @spec kind_from_stop_time_update(%{String.t() => any()}) :: nil | String.t()
  defp kind_from_stop_time_update(%{"arrival" => arrival, "departure" => departure}) do
    Filters.kinds() |> Map.get(arrival["uncertainty"] || departure["uncertainty"])
  end

  defp store_commuter_rail_predictions(%{"data" => data}, last_modified) do
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

        case prediction["relationships"]["vehicle"]["data"]["id"] do
          nil ->
            nil

          vehicle_id ->
            %{
              environment: "prod",
              file_timestamp: timestamp,
              vehicle_id: vehicle_id,
              trip_id: prediction["relationships"]["trip"]["data"]["id"],
              route_id: prediction["relationships"]["route"]["data"]["id"],
              direction_id: prediction["attributes"]["direction_id"],
              arrival_time: arrival_time_unix,
              departure_time: departure_time_unix,
              boarding_status: prediction["attributes"]["status"],
              schedule_relationship: prediction["attributes"]["schedule_relationship"],
              stop_id: prediction["relationships"]["stop"]["data"]["id"],
              stop_sequence: prediction["attributes"]["stop_sequence"]
            }
        end
      end)
      |> Enum.reject(&(&1 == nil))

    {_, _} = PredictionAnalyzer.Repo.insert_all(Prediction, predictions)
  end

  defp store_commuter_rail_predictions(_, _) do
    nil
  end
end
