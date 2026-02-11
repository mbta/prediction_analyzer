defmodule PredictionAnalyzer.Telemetry do
  @moduledoc """
  Telemetry event handlers.
  """
  require Logger

  @spec setup_telemetry() :: :ok
  def setup_telemetry do
    :telemetry.attach_many(
      "prediction-analyzer-handler",
      events(),
      &__MODULE__.handle_event/4,
      []
    )

    :ok
  end

  defp events do
    [
      # Other events to listen for go here
    ] ++ repo_events()
  end

  defp repo_events do
    prefix = PredictionAnalyzer.Repo.config()[:telemetry_prefix]

    [
      :insert_accuracy_query,
      :accuracy_context_query,
      :accuracies_query
    ]
    |> Enum.map(&(prefix ++ [&1]))
  end

  def handle_event(event, measurements, metadata, config)

  def handle_event(
        [:prediction_analyzer, :repo, :insert_accuracy_query],
        measures,
        _meta,
        _config
      ) do
    Logger.info("insert_accuracy_query_time #{query_time_log_fields(measures)}")
  end

  def handle_event(
        [:prediction_analyzer, :repo, :accuracy_context_query],
        measures,
        meta,
        _config
      ) do
    env = meta[:options][:env]
    request_params = inspect(meta[:options][:request_params])

    Logger.info(
      "accuracy_context_query_time env=#{env} #{query_time_log_fields(measures)} request_params=#{request_params}"
    )
  end

  def handle_event(
        [:prediction_analyzer, :repo, :accuracies_query],
        measures,
        meta,
        _config
      ) do
    env = meta[:options][:env]
    request_params = inspect(meta[:options][:request_params])

    Logger.info(
      "accuracies_query_time env=#{env} #{query_time_log_fields(measures)} request_params=#{request_params}"
    )
  end

  defp query_time_log_fields(measures) do
    # Note that the time_native variable binding doubles as a filter that discards nil values.
    for measure_name <- query_time_measures(), time_native = measures[measure_name] do
      time_ms = System.convert_time_unit(time_native, :native, :millisecond)
      "#{measure_name}_ms=#{time_ms}"
    end
    |> Enum.join(" ")
  end

  defp query_time_measures do
    [
      # the sum of query_time, queue_time, and decode_time
      :total_time,
      # the time spent executing the query
      :query_time,
      # the time spent waiting to check out a database connection
      :queue_time,
      # the time spent decoding the data received from the database
      :decode_time
    ]
  end
end
