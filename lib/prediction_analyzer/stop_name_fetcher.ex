defmodule PredictionAnalyzer.StopNameFetcher do
  require Logger
  use GenServer

  @type state() :: %{String.t() => String.t()}

  @spec start_link([any]) :: {:ok, pid}
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, opts)
  end

  @spec init(state) :: {:ok, state}
  def init(state) do
    send(self(), :load_stop_data)
    {:ok, state}
  end

  @spec get_stop_descriptions() :: %{String.t() => String.t()}
  def get_stop_descriptions() do
    GenServer.call(__MODULE__, :get_stop_descriptions)
  end

  @spec get_stop_name(String.t()) :: String.t()
  def get_stop_name(stop_id) do
    GenServer.call(__MODULE__, {:get_stop_name, stop_id})
  end

  def handle_call(:get_stop_descriptions, _from, state) do
    description_map =
      state
      |> Enum.map(fn {id, data} -> {id, data.description} end)
      |> Enum.into(%{})

    {:reply, description_map, state}
  end

  def handle_call({:get_stop_name, stop_id}, _from, state) do
    stop = state[stop_id]
    stop_name = if stop, do: "#{stop.name} (#{stop.platform_name})", else: stop_id
    {:reply, stop_name, state}
  end

  def handle_info(:load_stop_data, _state) do
    {:noreply, load_stop_data()}
  end

  @spec load_stop_data() :: state
  defp load_stop_data do
    url = Application.get_env(:prediction_analyzer, :stop_fetch_url)
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

  @spec parse_response(%HTTPoison.Response{}) :: state
  defp parse_response(http_response) do
    {:ok, body} = Jason.decode(http_response.body)

    body["data"]
    |> Enum.map(fn stop ->
      {stop["id"],
       %{
         description: stop["attributes"]["description"],
         name: stop["attributes"]["name"],
         platform_name: stop["attributes"]["platform_name"]
       }}
    end)
    |> Enum.into(%{})
  end
end
