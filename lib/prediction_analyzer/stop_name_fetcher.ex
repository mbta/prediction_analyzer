defmodule PredictionAnalyzer.StopNameFetcher do
  require Logger
  use GenServer

  def start_link(opts \\ []) do
    state = get_stop_names()
    GenServer.start_link(__MODULE__, state, opts)
  end

  def init(state) do
    {:ok, state}
  end

  def get_stop_map() do
    GenServer.call(__MODULE__, :get_stop_map)
  end

  def handle_call(:get_stop_map, _from, state), do: {:reply, state, state}

  defp get_stop_names do
    case HTTPoison.get("https://api-v3.mbta.com/stops?filter%5Broute_type%5D=0,1") do
      {:ok, response} ->
        parse_response(response)

      {:error, e} ->
        Logger.warn("Could not download stop names; received: #{inspect(e)}")
        %{}
    end
  end

  defp parse_response(http_response) do
    {:ok, body} = Jason.decode(http_response.body)

    body["data"]
    |> Enum.map(fn stop ->
      {"#{stop["attributes"]["name"]} (#{stop["id"]})", stop["id"]}
    end)
  end
end
