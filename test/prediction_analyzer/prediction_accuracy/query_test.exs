defmodule PredictionAnalyzer.PredictionAccuracy.QueryTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog
  import Ecto.Query, only: [from: 2]
  alias PredictionAnalyzer.Repo
  alias PredictionAnalyzer.PredictionAccuracy.PredictionAccuracy
  alias PredictionAnalyzer.VehicleEvents.VehicleEvent
  alias PredictionAnalyzer.Predictions.Prediction
  alias PredictionAnalyzer.PredictionAccuracy.Query

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(PredictionAnalyzer.Repo)
  end

  @prediction %Prediction{
    file_timestamp: :os.system_time(:second),
    vehicle_id: "vehicle",
    environment: "dev-green",
    trip_id: "trip",
    is_deleted: false,
    delay: 0,
    arrival_time: nil,
    boarding_status: nil,
    departure_time: nil,
    schedule_relationship: "SCHEDULED",
    stop_id: "stop",
    route_id: "route",
    direction_id: 0,
    stop_sequence: 10,
    stops_away: 2,
    vehicle_event_id: nil
  }

  @vehicle_event %VehicleEvent{
    vehicle_id: "vehicle",
    environment: "dev-green",
    vehicle_label: "label",
    is_deleted: false,
    route_id: "route",
    direction_id: 0,
    trip_id: "trip",
    stop_id: "stop",
    arrival_time: nil,
    departure_time: nil
  }

  defmodule FakeRepo do
    def query(_query, _params) do
      raise DBConnection.ConnectionError
    end
  end

  describe "calculate_aggregate_accuracy/9" do
    test "selects the right predictions based on bin and grades them accurately, for arrivals" do
      bin_name = "6-12 min"
      bin_min = 360
      bin_max = 720
      bin_error_min = -30
      bin_error_max = 60

      file_time = :os.system_time(:second) - 60 * 120
      arrival_time = file_time + 60 * 7

      %{id: ve_id} = Repo.insert!(%{@vehicle_event | arrival_time: arrival_time})

      Repo.insert!(%{
        @prediction
        | # too late to be considered
          file_timestamp: file_time + 60 * 90
      })

      Repo.insert!(%{
        @prediction
        | # too early to be considered
          file_timestamp: file_time - 60 * 90
      })

      Repo.insert!(%{
        @prediction
        | file_timestamp: file_time,
          route_id: "route1",
          stop_id: "stop1",
          # accurate
          # 15 sec error
          arrival_time: arrival_time - 15,
          vehicle_event_id: ve_id
      })

      Repo.insert!(%{
        @prediction
        | file_timestamp: file_time,
          route_id: "route1",
          stop_id: "stop1",
          # inaccurate
          # 45 sec error
          arrival_time: arrival_time - 45,
          vehicle_event_id: ve_id
      })

      Repo.insert!(%{
        @prediction
        | file_timestamp: file_time,
          route_id: "route1",
          stop_id: "stop1",
          # accurate
          # -45 sec error
          arrival_time: arrival_time + 45,
          vehicle_event_id: ve_id
      })

      Repo.insert!(%{
        @prediction
        | file_timestamp: file_time,
          route_id: "route1",
          stop_id: "stop1",
          # inaccurate
          # -65 sec error
          arrival_time: arrival_time + 65,
          vehicle_event_id: ve_id
      })

      {:ok, _} =
        Query.calculate_aggregate_accuracy(
          PredictionAnalyzer.Repo,
          Timex.local(),
          "arrival",
          bin_name,
          bin_min,
          bin_max,
          bin_error_min,
          bin_error_max,
          "dev-green"
        )

      [pa] = Repo.all(from(pa in PredictionAccuracy, select: pa))

      assert pa.stop_id == "stop1"
      assert pa.route_id == "route1"
      assert pa.arrival_departure == "arrival"
      assert pa.bin == "6-12 min"
      assert pa.num_predictions == 4
      assert pa.num_accurate_predictions == 2
      assert pa.direction_id == 0
      assert pa.mean_error == (15 + 45 + -45 + -65) / 4

      assert_in_delta(
        pa.root_mean_squared_error,
        :math.sqrt((15 * 15 + 45 * 45 + 45 * 45 + 65 * 65) / 4),
        0.001
      )
    end

    test "selects the right predictions based on bin and grades them accurately, for departures" do
      bin_name = "6-12 min"
      bin_min = 360
      bin_max = 720
      bin_error_min = -30
      bin_error_max = 60

      file_time = :os.system_time(:second) - 60 * 120
      departure_time = file_time + 60 * 7

      %{id: ve_id} = Repo.insert!(%{@vehicle_event | departure_time: departure_time})

      Repo.insert!(%{
        @prediction
        | # too late to be considered
          file_timestamp: file_time + 60 * 90
      })

      Repo.insert!(%{
        @prediction
        | # too early to be considered
          file_timestamp: file_time - 60 * 90
      })

      Repo.insert!(%{
        @prediction
        | file_timestamp: file_time,
          route_id: "route1",
          stop_id: "stop1",
          # accurate
          departure_time: departure_time - 15,
          vehicle_event_id: ve_id
      })

      Repo.insert!(%{
        @prediction
        | file_timestamp: file_time,
          route_id: "route1",
          stop_id: "stop1",
          # inaccurate
          departure_time: departure_time - 45,
          vehicle_event_id: ve_id
      })

      Repo.insert!(%{
        @prediction
        | file_timestamp: file_time,
          route_id: "route1",
          stop_id: "stop1",
          # accurate
          departure_time: departure_time + 45,
          vehicle_event_id: ve_id
      })

      Repo.insert!(%{
        @prediction
        | file_timestamp: file_time,
          route_id: "route1",
          stop_id: "stop1",
          # inaccurate
          departure_time: departure_time + 65,
          vehicle_event_id: ve_id
      })

      {:ok, _} =
        Query.calculate_aggregate_accuracy(
          PredictionAnalyzer.Repo,
          Timex.local(),
          "departure",
          bin_name,
          bin_min,
          bin_max,
          bin_error_min,
          bin_error_max,
          "dev-green"
        )

      [pa] = Repo.all(from(pa in PredictionAccuracy, select: pa))

      assert pa.stop_id == "stop1"
      assert pa.route_id == "route1"
      assert pa.arrival_departure == "departure"
      assert pa.bin == "6-12 min"
      assert pa.num_predictions == 4
      assert pa.num_accurate_predictions == 2
      assert pa.direction_id == 0
    end

    test "handles database failure properly" do
      log =
        capture_log([level: :warn], fn ->
          :error =
            Query.calculate_aggregate_accuracy(
              FakeRepo,
              Timex.local(),
              "departure",
              "6-12 min",
              360,
              720,
              -30,
              60,
              "dev-green"
            )
        end)

      base_log_msg =
        "Elixir.PredictionAnalyzer.PredictionAccuracy.Query do_calculate_aggregate_accuracy"

      assert log =~ "[warn] " <> base_log_msg
      assert log =~ "[error] " <> base_log_msg
    end

    test "calculates mean error and root mean squared error correctly" do
      bin_name = "6-12 min"
      bin_min = 360
      bin_max = 720
      bin_error_min = -30
      bin_error_max = 60

      file_time = :os.system_time(:second) - 60 * 120
      arrival_time = file_time + 60 * 7

      %{id: ve_id} = Repo.insert!(%{@vehicle_event | arrival_time: arrival_time})

      Repo.insert!(%{
        @prediction
        | file_timestamp: file_time,
          route_id: "route1",
          stop_id: "stop1",
          # 15 seconds optimistic
          arrival_time: arrival_time - 15,
          vehicle_event_id: ve_id
      })

      Repo.insert!(%{
        @prediction
        | file_timestamp: file_time,
          route_id: "route1",
          stop_id: "stop1",
          # 45 seconds optimistic
          arrival_time: arrival_time - 45,
          vehicle_event_id: ve_id
      })

      Repo.insert!(%{
        @prediction
        | file_timestamp: file_time,
          route_id: "route1",
          stop_id: "stop1",
          # 45 seconds pessimistic
          arrival_time: arrival_time + 45,
          vehicle_event_id: ve_id
      })

      Repo.insert!(%{
        @prediction
        | file_timestamp: file_time,
          route_id: "route1",
          stop_id: "stop1",
          # 65 seconds pessimistic
          arrival_time: arrival_time + 65,
          vehicle_event_id: ve_id
      })

      {:ok, _} =
        Query.calculate_aggregate_accuracy(
          PredictionAnalyzer.Repo,
          Timex.local(),
          "arrival",
          bin_name,
          bin_min,
          bin_max,
          bin_error_min,
          bin_error_max,
          "dev-green"
        )

      [pa] = Repo.all(from(pa in PredictionAccuracy, select: pa))

      assert pa.stop_id == "stop1"
      assert pa.route_id == "route1"
      assert pa.arrival_departure == "arrival"
      assert pa.bin == "6-12 min"
      assert pa.num_predictions == 4
      assert pa.num_accurate_predictions == 2
      assert pa.direction_id == 0
    end
  end
end
