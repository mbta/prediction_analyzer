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

  def get_stop_names do
    url = "https://api-v3.mbta.com/stops"
    api_key = Application.get_env(:prediction_analyzer, :api_v3_key)
    headers = if api_key, do: [{"x-api-key", api_key}], else: []
    params = %{"filter[route_type]" => "0,1"}

    http_fetcher = Application.get_env(:prediction_analyzer, :http_fetcher)

    case http_fetcher.get(url, headers, params: params) do
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
      {"#{stop["attributes"]["description"]} (#{stop["id"]})", stop["id"]}
    end)
    |> Enum.sort()
  end
end
