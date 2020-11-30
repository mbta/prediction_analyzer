defmodule PredictionAnalyzer.PredictionAccuracy.QueryTest do
  use ExUnit.Case, async: true
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
    vehicle_event_id: nil,
    kind: "mid_trip",
    nth_at_stop: 5
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

  describe "calculate_aggregate_accuracy/10" do
    test "selects the right predictions based on bin and grades them accurately" do
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
        | # different kind, should not be considered
          kind: "at_terminal"
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
          "mid_trip",
          false,
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
      assert pa.bin == "6-12 min"
      assert pa.kind == "mid_trip"
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

    test "grades only the predicted arrival time if available, otherwise the departure time" do
      bin_name = "6-12 min"
      bin_min = 360
      bin_max = 720
      bin_error_min = -30
      bin_error_max = 30
      file_time = :os.system_time(:second) - 60 * 120
      arrival_time = file_time + 60 * 7
      departure_time = file_time + 60 * 8

      %{id: ve_id} =
        Repo.insert!(%{
          @vehicle_event
          | arrival_time: arrival_time,
            departure_time: departure_time
        })

      Repo.insert!(%{
        @prediction
        | file_timestamp: file_time,
          route_id: "route",
          stop_id: "stop",
          # accurate arrival (10), inaccurate departure; should be graded accurate
          arrival_time: arrival_time - 10,
          departure_time: departure_time - 40,
          vehicle_event_id: ve_id
      })

      Repo.insert!(%{
        @prediction
        | file_timestamp: file_time,
          route_id: "route",
          stop_id: "stop",
          # inaccurate arrival (45), accurate departure; should be graded inaccurate
          arrival_time: arrival_time - 45,
          departure_time: departure_time - 15,
          vehicle_event_id: ve_id
      })

      Repo.insert!(%{
        @prediction
        | file_timestamp: file_time,
          route_id: "route",
          stop_id: "stop",
          # no predicted arrival, accurate departure (25); should be graded accurate
          departure_time: departure_time - 25,
          vehicle_event_id: ve_id
      })

      {:ok, _} =
        Query.calculate_aggregate_accuracy(
          PredictionAnalyzer.Repo,
          Timex.local(),
          "mid_trip",
          false,
          bin_name,
          bin_min,
          bin_max,
          bin_error_min,
          bin_error_max,
          "dev-green"
        )

      [pa] = Repo.all(from(pa in PredictionAccuracy, select: pa))

      assert pa.num_predictions == 3
      assert pa.num_accurate_predictions == 2
      assert_in_delta(pa.mean_error, (10 + 45 + 25) / 3, 0.000001)
    end

    test "handles in_next_two correctly, including NULL nth_at_stop" do
      bin_name = "6-12 min"
      bin_min = 360
      bin_max = 720
      bin_error_min = -30
      bin_error_max = 60
      file_time = :os.system_time(:second) - 60 * 120
      arrival_time = file_time + 60 * 7
      departure_time = file_time + 60 * 7

      %{id: ve_id} = Repo.insert!(%{@vehicle_event | departure_time: departure_time})

      # nth at stop 1, is in_next_two
      Repo.insert!(%{
        @prediction
        | file_timestamp: file_time,
          route_id: "route1",
          stop_id: "stop1",
          arrival_time: arrival_time,
          vehicle_event_id: ve_id,
          nth_at_stop: 1
      })

      # nth at stop 2, is in_next_two
      Repo.insert!(%{
        @prediction
        | file_timestamp: file_time,
          route_id: "route1",
          stop_id: "stop1",
          arrival_time: arrival_time,
          vehicle_event_id: ve_id,
          nth_at_stop: 2
      })

      # nth at stop 3, not in_next_two
      Repo.insert!(%{
        @prediction
        | file_timestamp: file_time,
          route_id: "route1",
          stop_id: "stop1",
          arrival_time: arrival_time,
          vehicle_event_id: ve_id,
          nth_at_stop: 3
      })

      # nth at stop null, not in_next_two
      Repo.insert!(%{
        @prediction
        | file_timestamp: file_time,
          route_id: "route1",
          stop_id: "stop1",
          arrival_time: arrival_time,
          vehicle_event_id: ve_id,
          nth_at_stop: nil
      })

      {:ok, _} =
        Query.calculate_aggregate_accuracy(
          PredictionAnalyzer.Repo,
          Timex.local(),
          "mid_trip",
          false,
          bin_name,
          bin_min,
          bin_max,
          bin_error_min,
          bin_error_max,
          "dev-green"
        )

      {:ok, _} =
        Query.calculate_aggregate_accuracy(
          PredictionAnalyzer.Repo,
          Timex.local(),
          "mid_trip",
          true,
          bin_name,
          bin_min,
          bin_max,
          bin_error_min,
          bin_error_max,
          "dev-green"
        )

      [pa_in_two] = Repo.all(from(pa in PredictionAccuracy, select: pa, where: pa.in_next_two))

      [pa_not_in_two] =
        Repo.all(from(pa in PredictionAccuracy, select: pa, where: not pa.in_next_two))

      assert pa_in_two.num_predictions == 2
      assert pa_not_in_two.num_predictions == 2
    end
  end
end
