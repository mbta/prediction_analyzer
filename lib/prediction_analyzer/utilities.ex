defmodule PredictionAnalyzer.Utilities do
  @type mode() :: :subway | :commuter_rail

  @doc """
  Returns the current service date and hour. The service
  date extends to 3am of the following day, so the hour can range
  from 3 - 26
  """
  @spec service_date_info(DateTime.t()) :: {Date.t(), non_neg_integer(), integer(), integer()}
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

  @doc """
  Returns the number of ms to the next 3am local time.
  """
  def ms_to_3am(local_now) do
    run_day =
      if local_now.hour < 3 do
        local_now
      else
        Timex.shift(local_now, days: 1)
      end

    run_day
    |> Timex.set(hour: 3, minute: 0, second: 0, microsecond: {0, 6})
    |> Timex.diff(local_now, :milliseconds)
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

  @spec route_param_to_list(String.t()) :: [String.t()]
  def route_param_to_list("Green-All"), do: ["Green-B", "Green-C", "Green-D", "Green-E"]

  def route_param_to_list("Light Rail"),
    do: ["Green-B", "Green-C", "Green-D", "Green-E", "Mattapan"]

  def route_param_to_list("Heavt Rail"), do: ["Red", "Orange", "Blue"]
  def route_param_to_list(param), do: [param]
end
