defmodule PredictionAnalyzer.Telemetry do
  @moduledoc """
  Telemetry event handlers.
  """
  require Logger

  @spec setup_telemetry() :: :ok
  def setup_telemetry do
    :telemetry.attach(
      "prediction-analyzer-handler",
      PredictionAnalyzer.Repo.config()[:telemetry_prefix] ++ [:named_query],
      &__MODULE__.handle_named_query_event/4,
      []
    )
  end

  @doc """
  Logs timing info for named DB queries.

  Requirements for this telemetry event to be handled correctly:
  - The query options must include the `:telemetry_options` opt.
  - `:telemetry_options` must be a KW list that has a `:name` key with a string or atom value.
  - `:telemetry_options` may include other keys with string or atom values.

  Logs will have the general form:

      "{name}_query_time {options_key1}={options_val1} ... {options_keyN}={options_valN} {time_fields}".

  E.g. if a query is executed with these opts:

      [
        telemetry_event: [:prediction_analyzer, :repo, :named_query],
        telemetry_options: [name: :accuracies_by_date, env: :prod, start_date: "2026-01-01", end_date: "2026-01-07"]
      ]

  The resulting log could look like:

      accuracies_by_date_query_time env=prod start_date=2026-01-01 end_date=2026-01-07 total_time_ms=40 query_time_ms==20
  """
  def handle_named_query_event(_event_name, measures, meta, _config) do
    {name, options} = Keyword.pop!(meta.options, :name)
    name = query_name_log_field(name)
    time_fields = query_time_log_fields(measures)
    extra_fields = extra_fields(options)

    [name, extra_fields, time_fields]
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.join(" ")
    |> Logger.info()
  end

  defp query_name_log_field(name) when is_binary(name) or is_atom(name) do
    "#{name}_query_time"
  end

  defp extra_fields(options) do
    options
    |> Enum.reject(&match?({_, nil}, &1))
    |> Enum.map_join(" ", fn
      {name, value} when is_binary(value) or is_atom(value) -> "#{name}=#{value}"
    end)
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
