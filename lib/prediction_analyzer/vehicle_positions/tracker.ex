defmodule PredictionAnalyzer.VehiclePositions.Tracker do
  use GenServer

  require Logger
  alias PredictionAnalyzer.VehiclePositions.Vehicle
  alias PredictionAnalyzer.VehiclePositions.Comparator

  @type vehicle_map :: %{Vehicle.vehicle_id() => Vehicle.t()}

  @type t :: %{
          http_fetcher: module(),
          aws_vehicle_positions_url: String.t(),
          vehicles: vehicle_map()
        }

  def start_link(opts \\ []) do
    aws_vehicle_positions_url =
      Keyword.get(
        opts,
        :aws_vehicle_positions_url,
        Application.get_env(:prediction_analyzer, :aws_vehicle_positions_url)
      )

    http_fetcher =
      Keyword.get(opts, :http_fetcher, Application.get_env(:prediction_analyzer, :http_fetcher))

    initial_state = %{
      aws_vehicle_positions_url: aws_vehicle_positions_url,
      http_fetcher: http_fetcher
    }

    GenServer.start_link(__MODULE__, initial_state)
  end

  def init(args) do
    state = Map.put(args, :vehicles, %{})
    schedule_fetch(self())
    {:ok, state}
  end

  def handle_info(:track_vehicles, state) do
    Logger.info("Downloading vehicle positions")

    %{body: body} = state.http_fetcher.get!(state.aws_vehicle_positions_url)

    {time, new_vehicles} =
      :timer.tc(fn ->
        body
        |> Jason.decode!()
        |> parse_vehicles
        |> Enum.into(%{}, fn v -> {v.id, v} end)
        |> Comparator.compare(state.vehicles)
      end)

    Logger.info("Processed #{length(Map.keys(new_vehicles))} vehicles in #{time / 1000} ms")
    schedule_fetch(self())
    {:noreply, %{state | vehicles: new_vehicles}}
  end

  def handle_info(msg, state) do
    Logger.warn("PredictionAnalyzer.VehiclePositions.Tracker unknown_message: #{inspect(msg)}")
    {:noreply, state}
  end

  defp parse_vehicles(%{"entity" => entities}) do
    Enum.flat_map(entities, fn e ->
      case Vehicle.from_json(e) do
        {:ok, vehicle} -> [vehicle]
        _ -> []
      end
    end)
  end

  defp parse_vehicles(_) do
    []
  end

  defp schedule_fetch(pid) do
    Process.send_after(pid, :track_vehicles, 1_000)
  end
end
