defmodule PredictionAnalyzer.Utilities do
  @doc """
  Returns the current service date and hour. The service
  date extends to 3am of the following day, so the hour can range
  from 3 - 26
  """
  @spec service_date_info(DateTime.t()) :: {Date.t(), non_neg_integer()}
  def service_date_info(timestamp) do
    beginning_of_hour_unix =
      timestamp
      |> Timex.set(minute: 0, second: 0, microsecond: {0, 6})
      |> DateTime.to_unix()

    end_of_hour_unix = beginning_of_hour_unix + 60 * 60

    {date, hour} =
      if timestamp.hour < 3 do
        hour = timestamp.hour + 24
        yesterday = timestamp |> Timex.shift(days: -1) |> DateTime.to_date()
        {yesterday, hour}
      else
        {DateTime.to_date(timestamp), timestamp.hour}
      end

    {date, hour, beginning_of_hour_unix, end_of_hour_unix}
  end

  @doc """
  Returns the number of ms to the top of the next hour.
  """
  @spec ms_to_next_hour(DateTime.t()) :: integer()
  def ms_to_next_hour(local_now \\ Timex.local()) do
    local_now
    |> Timex.shift(hours: 1)
    |> Timex.set(minute: 0, second: 30)
    |> Timex.diff(local_now, :milliseconds)
  end
end
