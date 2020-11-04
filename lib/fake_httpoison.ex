defmodule FakeHTTPoison do
  require Logger

  def get(
        "https://api-v3.mbta.com/stops",
        [],
        timeout: _,
        recv_timeout: _,
        params: %{"filter[route_type]" => "0,1"}
      ) do
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
        },
        %{
          "id" => "70150",
          "attributes" => %{
            "description" => "Kenmore - Green Line - Park Street & North",
            "name" => "Kenmore",
            "platform_name" => "Park Street & North"
          }
        },
        %{
          "id" => "71150",
          "attributes" => %{
            "description" => "Kenmore - Green Line - Park Street & North",
            "name" => "Kenmore",
            "platform_name" => "Park Street & North"
          }
        },
        %{
          "id" => "dummystop1",
          "attributes" => %{
            "description" => "Dummy Stop Description",
            "name" => "Dummy Stop Name",
            "platform_name" => nil
          }
        },
        %{
          "id" => "dummystop2",
          "attributes" => %{
            "description" => "Dummy Stop Description",
            "name" => "Dummy Stop Name",
            "platform_name" => nil
          }
        }
      ]
    }

    {:ok, %HTTPoison.Response{status_code: 200, body: Jason.encode!(body)}}
  end

  def get(
        "https://api-v3.mbta.com/stops",
        [],
        timeout: _,
        recv_timeout: _,
        params: %{"filter[route_type]" => "2"}
      ) do
    body = %{
      "data" => [
        %{
          "id" => "Andover",
          "attributes" => %{
            "description" => nil,
            "name" => "Andover",
            "platform_name" => nil
          }
        }
      ]
    }

    {:ok, %HTTPoison.Response{status_code: 200, body: Jason.encode!(body)}}
  end

  def get("https://bad-api-v3.mbta.com/stops", _headers, _params) do
    {:error, %HTTPoison.Error{}}
  end

  def get("https://bad-api-v3.mbta.com/predictions", _, _) do
    {:error, %HTTPoison.Error{}}
  end

  def get("https://api-v3.mbta.com/predictions" = url, _, _) do
    {:ok, prediction_response_body(url)}
  end

  def get(
        "https://api-v3.mbta.com/vehicles",
        _,
        timeout: 2000,
        recv_timeout: 2000,
        params: %{
          "filter[route]" =>
            "CR-Fitchburg,CR-Lowell,CR-Haverhill,CR-Newburyport,CR-Worcester,CR-Needham,CR-Franklin,CR-Providence,CR-Fairmount,CR-Middleborough,CR-Kingston,CR-Greenbush,CR-Foxboro"
        }
      ) do
    body = %{
      "data" => [
        %{
          "attributes" => %{
            "bearing" => 137,
            "current_status" => "IN_TRANSIT_TO",
            "current_stop_sequence" => 8,
            "direction_id" => 1,
            "label" => "1629",
            "latitude" => 42.376739501953125,
            "longitude" => -71.07559204101563,
            "speed" => 13,
            "updated_at" => "2019-03-28T13:57:57-04:00"
          },
          "id" => "1629",
          "links" => %{
            "self" => "/vehicles/1629"
          },
          "relationships" => %{
            "route" => %{
              "data" => %{
                "id" => "CR-Lowell",
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
                "id" => "CR-Weekday-Fall-18-324",
                "type" => "trip"
              }
            }
          },
          "type" => "vehicle"
        }
      ]
    }

    headers = [
      {"last-modified", "Sat, 10 Sep 1977 08:25:00 GMT"}
    ]

    {:ok, %HTTPoison.Response{status_code: 200, body: Jason.encode!(body), headers: headers}}
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
            "arrival_time" => "2019-03-28T15:31:00-04:00",
            "departure_time" => nil,
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
              "trip_id" => "TEST_TRIP_1",
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
                  "uncertainty" => 60
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
                  "uncertainty" => 60
                },
                "boarding_status" => nil,
                "departure" => %{
                  "delay" => nil,
                  "time" => 1_540_921_645,
                  "uncertainty" => 60
                },
                "schedule_relationship" => "SCHEDULED",
                "stop_id" => "70063",
                "stop_sequence" => 30,
                "stops_away" => 6
              },
              %{
                "arrival" => %{
                  "delay" => nil,
                  "time" => 1_540_921_700,
                  "uncertainty" => 60
                },
                "boarding_status" => nil,
                "departure" => %{
                  "delay" => nil,
                  "time" => 1_540_921_745,
                  "uncertainty" => 60
                },
                "schedule_relationship" => "SCHEDULED",
                "stop_id" => "70063",
                "stop_sequence" => 40,
                "stops_away" => nil
              }
            ]
          }
        },
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
              "trip_id" => "TEST_TRIP_2",
              "route_id" => "Red",
              "direction_id" => 1
            },
            "stop_time_update" => [
              %{
                "arrival" => nil,
                "boarding_status" => nil,
                "departure" => %{
                  "delay" => nil,
                  "time" => 1_540_921_562,
                  "uncertainty" => 60
                },
                "schedule_relationship" => "SCHEDULED",
                "stop_id" => "Alewife-01",
                "stop_sequence" => 10,
                "stops_away" => 0
              },
              %{
                "arrival" => %{
                  "delay" => nil,
                  "time" => 1_540_921_660,
                  "uncertainty" => 60
                },
                "boarding_status" => nil,
                "departure" => %{
                  "delay" => nil,
                  "time" => 1_540_921_705,
                  "uncertainty" => 60
                },
                "schedule_relationship" => "SCHEDULED",
                "stop_id" => "70063",
                "stop_sequence" => 20,
                "stops_away" => 1
              }
            ]
          }
        },
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
              "trip_id" => "TEST_TRIP_3",
              "route_id" => "Red",
              "direction_id" => 1
            },
            "stop_time_update" => nil
          }
        },
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
              "trip_id" => "TEST_TRIP_4",
              "route_id" => "Red",
              "direction_id" => 1
            },
            "stop_time_update" => [
              %{
                "arrival" => nil,
                "boarding_status" => nil,
                "departure" => %{
                  "delay" => nil,
                  "time" => 1_540_921_562,
                  "uncertainty" => 60
                },
                "schedule_relationship" => "SCHEDULED",
                "stop_id" => nil,
                "stop_sequence" => 10,
                "stops_away" => 0
              }
            ]
          }
        },
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
              "trip_id" => "TEST_TRIP_5",
              "route_id" => "Red",
              "direction_id" => 1
            },
            "stop_time_update" => [
              %{
                "arrival" => nil,
                "boarding_status" => nil,
                "departure" => nil,
                "passthrough_time" => 1_540_921_705,
                "schedule_relationship" => "SKIPPED",
                "stop_id" => "70063",
                "stop_sequence" => 20,
                "stops_away" => 1
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
