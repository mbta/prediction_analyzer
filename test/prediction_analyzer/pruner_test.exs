defmodule PredictionAnalyzer.PrunerTest do
  use ExUnit.Case, async: false

  alias PredictionAnalyzer.Pruner
  alias PredictionAnalyzer.VehicleEvents.VehicleEvent
  alias PredictionAnalyzer.Predictions.Prediction
  alias PredictionAnalyzer.Repo

  import Ecto.Query, only: [from: 2]

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(PredictionAnalyzer.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(PredictionAnalyzer.Repo, {:shared, self()})
  end

  @prediction %Prediction{
    file_timestamp: :os.system_time(:second),
    vehicle_id: "vehicle",
    trip_id: "trip",
    is_deleted: false,
    delay: 0,
    arrival_time: nil,
    boarding_status: nil,
    departure_time: nil,
    schedule_relationship: "SCHEDULED",
    stop_id: "stop",
    route_id: "route",
    stop_sequence: 10,
    stops_away: 2,
    vehicle_event_id: nil
  }

  @vehicle_event %VehicleEvent{
    vehicle_id: "vehicle",
    vehicle_label: "label",
    is_deleted: false,
    route_id: "route",
    direction_id: 0,
    trip_id: "trip",
    stop_id: "stop",
    arrival_time: nil,
    departure_time: nil
  }

  test "starts up with no issue" do
    {:ok, pid} = Pruner.start_link([])
    :timer.sleep(500)
    assert Process.alive?(pid)
  end

  test "prune deletes predictions that are older than 28 days old with dwell time grace period for vehicle events" do
    max_dwell_time_sec = Application.get_env(:prediction_analyzer, :max_dwell_time_sec)
    prune_lookback_sec = Application.get_env(:prediction_analyzer, :prune_lookback_sec)

    prune_cutoff = System.system_time(:second) - prune_lookback_sec
    old_timestamp = prune_cutoff - max_dwell_time_sec - 15
    grace_timestamp = prune_cutoff - max_dwell_time_sec + 15
    new_timestamp = prune_cutoff + 15

    %{id: ve_old} = Repo.insert!(%{@vehicle_event | arrival_time: old_timestamp})
    %{id: ve_grace} = Repo.insert!(%{@vehicle_event | arrival_time: grace_timestamp})
    %{id: ve_new} = Repo.insert!(%{@vehicle_event | arrival_time: new_timestamp})

    %{id: p_old} =
      Repo.insert!(%{@prediction | file_timestamp: old_timestamp, vehicle_event_id: ve_old})

    %{id: p_grace} =
      Repo.insert!(%{@prediction | file_timestamp: grace_timestamp, vehicle_event_id: ve_old})

    %{id: p_new} = Repo.insert!(%{@prediction | file_timestamp: new_timestamp})

    assert Repo.one(from(ve in VehicleEvent, select: fragment("count(*)"))) == 3
    assert Repo.one(from(p in Prediction, select: fragment("count(*)"))) == 3

    {:noreply, []} = Pruner.handle_info(:prune, [])

    vehicle_event_ids = Repo.all(from(ve in VehicleEvent, select: ve.id))
    prediction_ids = Repo.all(from(p in Prediction, select: p.id))

    refute ve_old in vehicle_event_ids
    assert ve_grace in vehicle_event_ids
    assert ve_new in vehicle_event_ids

    refute p_old in prediction_ids
    refute p_grace in prediction_ids
    assert p_new in prediction_ids
  end
end
