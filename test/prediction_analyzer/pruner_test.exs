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
    {:ok, pid} = Pruner.start_link()
    :timer.sleep(500)
    assert Process.alive?(pid)
  end

  test "prune deletes data that is longer than 28 days old and leaves new data alone" do
    days_ago_29 = Timex.local() |> Timex.shift(days: -29) |> DateTime.to_unix()

    days_ago_just_under_28 =
      Timex.local() |> Timex.shift(days: -28) |> Timex.shift(minutes: 15) |> DateTime.to_unix()

    days_ago_5 = Timex.local() |> Timex.shift(days: -5) |> DateTime.to_unix()

    %{id: ve1} = Repo.insert!(%{@vehicle_event | arrival_time: days_ago_29})
    %{id: ve2} = Repo.insert!(%{@vehicle_event | arrival_time: days_ago_5})
    %{id: _ve3} = Repo.insert!(%{@vehicle_event | arrival_time: days_ago_just_under_28})
    %{id: _ve4} = Repo.insert!(%{@vehicle_event | arrival_time: days_ago_29})
    %{id: _p1} = Repo.insert!(%{@prediction | file_timestamp: days_ago_29, vehicle_event_id: ve1})
    %{id: _p2} = Repo.insert!(%{@prediction | file_timestamp: days_ago_29})
    %{id: p3} = Repo.insert!(%{@prediction | file_timestamp: days_ago_5})

    assert Repo.one(from(ve in VehicleEvent, select: fragment("count(*)"))) == 4
    assert Repo.one(from(p in Prediction, select: fragment("count(*)"))) == 3

    {:noreply, []} = Pruner.handle_info(:prune, [])

    assert [%{id: ^ve2}] = Repo.all(from(ve in VehicleEvent, select: ve))
    assert [%{id: ^p3}] = Repo.all(from(p in Prediction, select: p))
  end
end
