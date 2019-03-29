defmodule FakeHTTPoison do
  require Logger

  def get("https://api-v3.mbta.com/stops", _headers, params: %{"filter[route_type]" => "0,1"}) do
    body = %{
      "data" => [
        %{
          "id" => "70197",
          "attributes" => %{
            "description" => "Park Street - Green Line - (C) Cleveland Circle",
            "name" => "Park St",
            "platform_name" => "Cleveland Circle"
          }
        },
        %{
          "id" => "70238",
          "attributes" => %{
            "description" => "Cleveland Circle - Green Line - Park Street & North",
            "name" => "Cleveland Circle",
            "platform_name" => "Park Street & North"
          }
        },
        %{
          "id" => "70007",
          "attributes" => %{
            "description" => "Jackson Square - Orange Line - Oak Grove",
            "name" => "Jackson Sq",
            "platform_name" => "Oak Grove"
          }
        }
      ]
    }

    response = %HTTPoison.Response{body: Jason.encode!(body)}
    {:ok, response}
  end

  def get("https://api-v3.mbta.com/stops", _headers, params: %{"filter[route_type]" => "2"}) do
    body = %{
      "data" => []
    }

    response = %HTTPoison.Response{body: Jason.encode!(body)}
    {:ok, response}
  end

  def get("https://api-v3.mbta.com/bad_stops", _headers, _params) do
    {:error, %HTTPoison.Error{}}
  end

  def get!("https://api-v3.mbta.com/predictions" = url, _, _) do
    prediction_response_body(url)
  end

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

  defp prediction_response_body("https://api-v3.mbta.com/predictions" = url) do
    body = %{
      "data" => [
        %{
          "attributes" => %{
            "arrival_time" => nil,
            "departure_time" => "2019-03-28T15:31:00-04:00",
            "direction_id" => 0,
            "schedule_relationship" => nil,
            "status" => "On time",
            "stop_sequence" => 1
          },
          "id" => "prediction-CR-Weekday-Fall-18-415-LittletonWachusett-North Station-1",
          "relationships" => %{
            "route" => %{
              "data" => %{
                "id" => "CR-Fitchburg",
                "type" => "route"
              }
            },
            "vehicle" => %{
              "data" => %{
                "id" => "vehicle_id",
                "type" => "vehicle"
              }
            },
            "stop" => %{
              "data" => %{
                "id" => "North Station",
                "type" => "stop"
              }
            },
            "trip" => %{
              "data" => %{
                "id" => "CR-Weekday-Fall-18-415-LittletonWachusett",
                "type" => "trip"
              }
            }
          },
          "type" => "prediction"
        },
        %{
          "attributes" => %{
            "arrival_time" => nil,
            "departure_time" => "2019-03-28T15:31:00-04:00",
            "direction_id" => 0,
            "schedule_relationship" => nil,
            "status" => "On time",
            "stop_sequence" => 1
          },
          "id" => "prediction-CR-Weekday-Fall-18-415-LittletonWachusett-North Station-1",
          "relationships" => %{
            "route" => %{
              "data" => %{
                "id" => "CR-Fitchburg",
                "type" => "route"
              }
            },
            "stop" => %{
              "data" => %{
                "id" => "North Station",
                "type" => "stop"
              }
            },
            "trip" => %{
              "data" => %{
                "id" => "CR-Weekday-Fall-18-415-LittletonWachusett",
                "type" => "trip"
              }
            }
          },
          "type" => "prediction"
        }
      ]
    }

    %HTTPoison.Response{
      body: Jason.encode!(body),
      headers: [
        {"x-amz-id-2",
         "MMXRCAYRX5tKu1Yx0n5yWk3l+rk76RvWd3jz9wmqDl4Wud+G+t0PE5ZRqGJUzgkFEAzmTAE9kx0="},
        {"x-amz-request-id", "B96B029654DDF30A"},
        {"Date", "Tue, 30 Oct 2018 17:33:16 GMT"},
        {"last-modified", "Tue, 30 Oct 2018 17:33:15 GMT"},
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
      request_url: "https://api-v3.mbta.com/predictions",
      status_code: 200
    }
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
              "route_id" => "Red",
              "direction_id" => 1
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
