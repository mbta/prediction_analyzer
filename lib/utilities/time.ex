defmodule Utilities.Time do
  def format_unix(nil) do
    "N/A"
  end

  def format_unix(unix) do
    DateTime.from_unix!(unix, :second)
    |> DateTime.shift_zone!("America/New_York")
    |> DateTime.to_string()
  end
end
