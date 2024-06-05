defmodule Utilities.Time do
  def format_unix(nil) do
    "N/A"
  end

  def format_unix(unix) do
    DateTime.from_unix!(unix, :second)
    |> DateTime.shift_zone!("America/New_York")
    |> Calendar.strftime("%Y-%m-%d %H:%M:%S %Z")
  end
end
