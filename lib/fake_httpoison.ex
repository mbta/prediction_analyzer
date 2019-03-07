defmodule FakeHTTPoison do
  require Logger

  def get!("https://prod.example.com/mbta-gtfs-s3/rtr/TripUpdates_enhanced.json" = url) do
    prediction_response_body(url)
  end

  def get!("https://dev_green.example.com/mbta-gtfs-s3/rtr/TripUpdates_enhanced.json" = url) do
    prediction_response_body(url)
  end

  def get!(url) do
    Logger.info("fetched #{url}")
    %{body: "{}"}
  end

  defp prediction_response_body(url) do
    body = %{
      "entity" => [
        %{
          "alert" => nil,
          "id" => "1540920791_ADDED-1540403419",
          "is_deleted" => false,
          "trip_update" => %{
            "delay" => nil,
            "vehicle" => %{
              "id" => "vehicle_id"
            },
            "trip" => %{
              "trip_id" => "TEST_TRIP",
              "route_id" => "Red"
            },
            "stop_time_update" => [
              %{
                "arrival" => nil,
                "boarding_status" => nil,
                "departure" => %{
                  "delay" => nil,
                  "time" => 1_540_921_502,
                  "uncertainty" => nil
                },
                "schedule_relationship" => "SCHEDULED",
                "stop_id" => "Alewife-01",
                "stop_sequence" => 20,
                "stops_away" => 5
              },
              %{
                "arrival" => %{
                  "delay" => nil,
                  "time" => 1_540_921_600,
                  "uncertainty" => nil
                },
                "boarding_status" => nil,
                "departure" => %{
                  "delay" => nil,
                  "time" => 1_540_921_645,
                  "uncertainty" => nil
                },
                "schedule_relationship" => "SCHEDULED",
                "stop_id" => "70063",
                "stop_sequence" => 30,
                "stops_away" => 6
              }
            ]
          }
        }
      ],
      "header" => %{"timestamp" => 123_345_532}
    }

    %HTTPoison.Response{
      body: Jason.encode!(body),
      headers: [
        {"x-amz-id-2",
         "MMXRCAYRX5tKu1Yx0n5yWk3l+rk76RvWd3jz9wmqDl4Wud+G+t0PE5ZRqGJUzgkFEAzmTAE9kx0="},
        {"x-amz-request-id", "B96B029654DDF30A"},
        {"Date", "Tue, 30 Oct 2018 17:33:16 GMT"},
        {"Last-Modified", "Tue, 30 Oct 2018 17:33:15 GMT"},
        {"ETag", "\"78891d89780b999f2854e782a5fe5d24\""},
        {"Accept-Ranges", "bytes"},
        {"Content-Type", "application/octet-stream"},
        {"Content-Length", "513838"},
        {"Server", "AmazonS3"}
      ],
      request: %HTTPoison.Request{
        body: "",
        headers: [],
        method: :get,
        options: [],
        params: %{},
        url: url
      },
      request_url: "https://s3.amazonaws.com/mbta-gtfs-s3/rtr/TripUpdates_enhanced.json",
      status_code: 200
    }
  end
end
