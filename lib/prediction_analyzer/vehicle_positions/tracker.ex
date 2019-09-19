defmodule PredictionAnalyzer.VehiclePositions.Tracker do
  use GenServer

  require Logger
  alias PredictionAnalyzer.VehiclePositions.Vehicle
  alias PredictionAnalyzer.VehiclePositions.Comparator

  @type vehicle_map :: %{Vehicle.vehicle_id() => Vehicle.t()}

  @type t :: %{
          http_fetcher: module(),
          environment: String.t(),
          aws_vehicle_positions_url: String.t(),
          subway_vehicles: vehicle_map(),
          subway_last_modified: String.t(),
          commuter_rail_vehicles: vehicle_map(),
          commuter_rail_last_modified: String.t()
        }

  def start_link(_opts \\ [], args) do
    environment =
      Keyword.get(
        args,
        :environment
      )

    aws_vehicle_positions_url =
      get_env_vehicle_positions_url(environment) || args[:aws_vehicle_positions_url]

    http_fetcher =
      Keyword.get(args, :http_fetcher, Application.get_env(:prediction_analyzer, :http_fetcher))

    initial_state = %{
      aws_vehicle_positions_url: aws_vehicle_positions_url,
      environment: environment,
      http_fetcher: http_fetcher,
      commuter_rail_last_modified: "Thu, 01 Jan 1970 00:00:00 GMT",
      subway_last_modified: "Thu, 01 Jan 1970 00:00:00 GMT"
    }

    GenServer.start_link(__MODULE__, initial_state)
  end

  def init(args) do
    state = Map.merge(args, %{subway_vehicles: %{}, commuter_rail_vehicles: %{}})

    schedule_subway_fetch(self())
    schedule_commuter_rail_fetch(self())
    {:ok, state}
  end

  def handle_info(:track_subway_vehicles, state) do
    Logger.info("Downloading vehicle positions")

    schedule_subway_fetch(self())

    case state.http_fetcher.get(state.aws_vehicle_positions_url, [
           {"If-Modified-Since", state.subway_last_modified}
         ]) do
      {:ok, %{status_code: 200, body: body, headers: headers}} ->
        {time, new_vehicles} =
          :timer.tc(fn ->
            body
            |> Jason.decode!()
            |> parse_vehicles(state.environment)
            |> Enum.into(%{}, fn v -> {v.id, v} end)
            |> Comparator.compare(state.subway_vehicles)
          end)

        new_last_modified_timestamp = extract_last_modified(headers) || state.subway_last_modified

        Logger.info("Processed #{length(Map.keys(new_vehicles))} vehicles in #{time / 1000} ms")

        {:noreply,
         %{
           state
           | subway_vehicles: new_vehicles,
             subway_last_modified: new_last_modified_timestamp
         }}

      {:ok, %{status_code: 304}} ->
        Logger.warn(
          "Subway vehicle positions not modified since last request at #{
            state.subway_last_modified
          }"
        )

        {:noreply, state}

      {:error, e} ->
        Logger.warn("Could not download subway vehicles; received: #{inspect(e)}")
        {:noreply, state}
    end
  end

  def handle_info(:track_commuter_rail_vehicles, %{environment: "dev-green"} = state) do
    {:noreply, state}
  end

  def handle_info(:track_commuter_rail_vehicles, state) do
    url_path = "vehicles"

    params = %{
      "filter[route]" =>
        :commuter_rail |> PredictionAnalyzer.Utilities.routes_for_mode() |> Enum.join(",")
    }

    schedule_commuter_rail_fetch(self())

    state =
      case PredictionAnalyzer.Utilities.APIv3.request(
             url_path,
             [{"If-Modified-Since", state.commuter_rail_last_modified}],
             params: params
           ) do
        {:ok, %{body: body, headers: headers}} ->
          new_vehicles =
            body
            |> Jason.decode!()
            |> Map.get("data")
            |> parse_commuter_rail("prod")
            |> Enum.into(%{}, fn v -> {v.id, v} end)
            |> Comparator.compare(state.commuter_rail_vehicles)

          new_last_modified_timestamp =
            extract_last_modified(headers) || state.commuter_rail_last_modified

          %{
            state
            | commuter_rail_vehicles: new_vehicles,
              commuter_rail_last_modified: new_last_modified_timestamp
          }

        {:error, %{status_code: 304}} ->
          Logger.warn(
            "Commuter rail vehicle positions not modified since last request at #{
              state.commuter_rail_last_modified
            }"
          )

          state

        {:error, e} ->
          Logger.warn("Could not download commuter rail vehicles; received: #{inspect(e)}")
          state
      end

    {:noreply, state}
  end

  def handle_info(msg, state) do
    Logger.warn("PredictionAnalyzer.VehiclePositions.Tracker unknown_message: #{inspect(msg)}")
    {:noreply, state}
  end

  defp parse_vehicles(%{"entity" => entities}, environment) do
    Enum.flat_map(entities, fn e ->
      case Vehicle.from_json(e, environment) do
        {:ok, vehicle} ->
          [vehicle]

        _ ->
          Logger.warn("failed_to_parse_vehicle_entity #{inspect(e)}")
          []
      end
    end)
  end

  defp parse_vehicles(_, _) do
    []
  end

  defp parse_commuter_rail(data, _env) do
    Enum.flat_map(data, fn d ->
      case Vehicle.parse_commuter_rail(d) do
        {:ok, vehicle} -> [vehicle]
        _ -> []
      end
    end)
  end

  def get_env_vehicle_positions_url("dev-green") do
    Application.get_env(:prediction_analyzer, :dev_green_aws_vehicle_positions_url)
  end

  def get_env_vehicle_positions_url("prod") do
    Application.get_env(:prediction_analyzer, :aws_vehicle_positions_url)
  end

  @spec schedule_subway_fetch(pid() | atom()) :: reference
  defp schedule_subway_fetch(pid) do
    Process.send_after(pid, :track_subway_vehicles, 1_000)
  end

  @spec schedule_commuter_rail_fetch(pid() | atom()) :: reference
  defp schedule_commuter_rail_fetch(pid) do
    Process.send_after(pid, :track_commuter_rail_vehicles, 10_500)
  end

  @spec extract_last_modified([{String.t(), String.t()}]) :: String.t() | nil
  defp extract_last_modified(headers) do
    case Enum.find(headers, fn {key, _value} -> String.downcase(key) == "last-modified" end) do
      {_key, value} -> value
      nil -> nil
    end
  end
end
