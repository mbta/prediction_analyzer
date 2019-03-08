defmodule PredictionAnalyzer.StopNameFetcher do
  require Logger
  use GenServer

  @type state() :: %{String.t() => String.t()}

  @spec start_link([any]) :: {:ok, pid}
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, [{"", ""}], opts)
  end

  @spec init(state) :: {:ok, state}
  def init(state) do
    send(self(), :get_stop_names)
    {:ok, state}
  end

  @spec get_stop_map() :: {:reply, state, state}
  def get_stop_map(pid \\ __MODULE__) do
    real_pid =
      if is_pid(pid) do
        pid
      else
        Process.whereis(pid)
      end

    if real_pid && Process.alive?(real_pid) do
      GenServer.call(real_pid, :get_stop_map)
    else
      [{"", ""}]
    end
  end

  @spec handle_call(:get_stop_map, GenServer.from(), state) :: {:reply, state, state}
  def handle_call(:get_stop_map, _from, state), do: {:reply, state, state}

  def handle_info(:get_stop_names, _state) do
    {:noreply, get_stop_names()}
  end

  @spec get_stop_names() :: state
  defp get_stop_names do
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
        %{"" => ""}
    end
  end

  @spec parse_response(%HTTPoison.Response{}) :: state
  defp parse_response(http_response) do
    {:ok, body} = Jason.decode(http_response.body)

    body["data"]
    |> Enum.map(fn stop ->
      {stop["id"], stop["attributes"]["description"]}
    end)
    |> Enum.into(%{"" => ""})
  end
end
