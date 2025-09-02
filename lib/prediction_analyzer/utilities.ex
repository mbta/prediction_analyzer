defmodule PredictionAnalyzer.Utilities do
  @type mode() :: :subway | :commuter_rail

  @doc """
  Returns the current service date, hour, and 5m increment. The service
  date extends to 3am of the following day, so the hour can range
  from 3 - 26
  """
  @spec service_date_info(DateTime.t()) ::
          {Date.t(), non_neg_integer(), non_neg_integer(), integer(), integer()}
  def service_date_info(timestamp) do
    minute = start_of_current_5m_block(timestamp)

    beginning_of_5m_unix =
      timestamp
      |> Timex.set(minute: minute, second: 0, microsecond: {0, 6})
      |> DateTime.to_unix()

    end_of_5m_unix = beginning_of_5m_unix + 300

    {date, hour} =
      if timestamp.hour < 3 do
        hour = timestamp.hour + 24
        yesterday = timestamp |> Timex.shift(days: -1) |> DateTime.to_date()
        {yesterday, hour}
      else
        {DateTime.to_date(timestamp), timestamp.hour}
      end

    {date, hour, minute, beginning_of_5m_unix, end_of_5m_unix}
  end

  @spec get_week_range(DateTime.t()) :: {Date.t(), Date.t()}
  def get_week_range(timestamp) do
    beginning_of_week =
      timestamp
      |> Timex.set(hour: 3, minute: 0, second: 0, microsecond: {0, 6})

    end_of_week = Timex.shift(beginning_of_week, days: 6)

    {DateTime.to_date(beginning_of_week), DateTime.to_date(end_of_week)}
  end

  @doc """
  Returns the number of ms to the top of the next 5m segment.
  """
  def ms_to_next_5m(local_now \\ Timex.local()) do
    %{minute: current_minute} = local_now

    minute_shift = 5 - rem(current_minute, 5)

    local_now
    |> Timex.shift(minutes: minute_shift)
    |> Timex.set(second: 30)
    |> Timex.diff(local_now, :milliseconds)
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

  @doc """
  Returns the ms until end of week
  """
  @spec ms_to_next_week(DateTime.t()) :: integer()
  def ms_to_next_week(local_now \\ Timex.local()) do
    days_to_end_of_week =
      local_now
      |> Timex.days_to_end_of_week(:sun)

    case days_to_end_of_week do
      0 ->
        local_now
        |> Timex.shift(days: 7)
        |> Timex.set(hour: 1, minute: 0, second: 0)
        |> Timex.diff(local_now, :milliseconds)

      n ->
        local_now
        |> Timex.shift(days: n)
        |> Timex.set(hour: 1, minute: 0, second: 0)
        |> Timex.diff(local_now, :milliseconds)
    end
  end

  @spec generic_stop_id(String.t()) :: String.t()
  def generic_stop_id("Alewife-01"), do: "70061"
  def generic_stop_id("Alewife-02"), do: "70061"
  def generic_stop_id("Braintree-01"), do: "70105"
  def generic_stop_id("Braintree-02"), do: "70105"
  def generic_stop_id("Forest Hills-01"), do: "70001"
  def generic_stop_id("Forest Hills-02"), do: "70001"
  def generic_stop_id("Oak Grove-01"), do: "70036"
  def generic_stop_id("Oak Grove-02"), do: "70036"
  def generic_stop_id("Union Square-" <> _), do: "70503"
  # Trains incoming at 70511 will later show up as stopped at 70512
  def generic_stop_id("70511"), do: "70512"
  def generic_stop_id(stop_id), do: stop_id

  @spec routes_for_mode(atom()) :: [String.t()]
  def routes_for_mode(:subway) do
    ["Red", "Blue", "Orange", "Green-B", "Green-C", "Green-D", "Green-E", "Mattapan"]
  end

  def routes_for_mode(:commuter_rail) do
    [
      "CR-Fitchburg",
      "CR-Lowell",
      "CR-Haverhill",
      "CR-Newburyport",
      "CR-Worcester",
      "CR-Needham",
      "CR-Franklin",
      "CR-Providence",
      "CR-Fairmount",
      "CR-Middleborough",
      "CR-Kingston",
      "CR-Greenbush",
      "CR-Foxboro"
    ]
  end

  @spec string_to_mode(String.t()) :: :subway | :commuter_rail
  def string_to_mode("commuter_rail"), do: :commuter_rail
  def string_to_mode(_), do: :subway

  defp start_of_current_5m_block(%DateTime{minute: minute}) do
    trunc(minute / 5) * 5
  end
end
