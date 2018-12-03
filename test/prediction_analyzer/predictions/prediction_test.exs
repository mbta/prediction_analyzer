defmodule PredictionAnalyzer.Predictions.PredictionTest do
  use ExUnit.Case, async: true

  alias PredictionAnalyzer.Predictions.Prediction
  alias PredictionAnalyzer.VehicleEvents.VehicleEvent

  describe "to_csv/1" do
    test "converts predictions into a CSV" do
      predictions = [
        %Prediction{
          environment: "prod",
          file_timestamp: 123,
          arrival_time: 234,
          trip_id: "trip1",
          stop_id: "stop1",
          route_id: "route1"
        },
        %Prediction{
          vehicle_event: %VehicleEvent{
            vehicle_id: "vehicle1"
          }
        }
      ]

      lines =
        predictions
        |> Prediction.to_csv()
        |> String.split()

      assert lines == [
               "env,file_timestamp,is_deleted,delay,boarding_status,schedule_relationship,stop_sequence,stops_away,trip_id,trip_vehicle_id,route_id,stop_id,predicted_arrival,predicted_departure,vehicle_id,vehicle_label,vehicle_direction_id,actual_arrival,actual_departure",
               "prod,123,,,,,,,trip1,,route1,stop1,234,,,,,,",
               ",,,,,,,,,,,,,,vehicle1,,,,"
             ]
    end
  end
end
