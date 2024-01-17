defmodule PredictionAnalyzerWeb.TerminalDepartureController do
  use PredictionAnalyzerWeb, :controller
  import Ecto.Query, only: [from: 2]
  alias PredictionAnalyzer.Predictions.Prediction
  alias PredictionAnalyzer.VehicleEvents.VehicleEvent

  def index(conn, _params) do
    #     select route_id, count(*) as cnt
    # from vehicle_events
    # where not exists(
    #     select id
    #     from predictions
    #     where predictions.vehicle_event_id = vehicle_events.id
    #     and predictions.file_timestamp < vehicle_events.departure_time
    # )
    # and environment='prod'
    # and trip_id is not null
    # and departure_time is not null
    # and not is_deleted
    # group by route_id
    # order by cnt desc;
    query =
      from(ve in VehicleEvent,
        as: :vehicle_event,
        where:
          not is_nil(ve.trip_id) and
            not is_nil(ve.departure_time) and
            not ve.is_deleted and
            ve.environment == "prod" and
            not exists(
              from(p in Prediction,
                where:
                  p.vehicle_event_id == parent_as(:vehicle_event).id and
                    p.file_timestamp < parent_as(:vehicle_event).departure_time
              )
            ),
        group_by: ve.route_id,
        order_by: [desc: count(ve.id)],
        select: {ve.route_id, count(ve.id)}
      )

    results = PredictionAnalyzer.Repo.all(query)

    render(conn, "index.html", results: results)
  end
end
