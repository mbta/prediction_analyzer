defmodule PredictionAnalyzer.StopNameFetcher do
  require Logger
  use GenServer

  @type stop_info :: %{
          description: String.t(),
          name: String.t(),
          platform_name: String.t()
        }
  @type state() :: %{PredictionAnalyzer.Utilities.mode() => %{String.t() => stop_info()}}

  @spec start_link([any]) :: {:ok, pid}
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, opts)
  end

  @spec init(state) :: {:ok, state}
  def init(state) do
    send(self(), :load_stop_data)
    {:ok, state}
  end

  @spec get_stop_descriptions(PredictionAnalyzer.Utilities.mode()) :: %{String.t() => String.t()}
  def get_stop_descriptions(mode) do
    GenServer.call(__MODULE__, {:get_stop_descriptions, mode})
  end

  @spec get_stop_name(PredictionAnalyzer.Utilities.mode(), String.t()) :: String.t()
  def get_stop_name(mode, stop_id) do
    GenServer.call(__MODULE__, {:get_stop_name, mode, stop_id})
  end

  def handle_call({:get_stop_descriptions, mode}, _from, state) do
    description_map =
      state
      |> Map.get(mode)
      |> Enum.map(fn {id, data} -> {id, data.description} end)
      |> Enum.into(%{})

    {:reply, description_map, state}
  end

  def handle_call({:get_stop_name, mode, stop_id}, _from, state)
      when mode in [:commuter_rail, :subway] do
    stop_name =
      case state[mode][stop_id] do
        nil ->
          stop_id

        %{platform_name: nil} = stop ->
          if unique_stop_info?(state[mode], state[mode][stop_id]) do
            stop.name
          else
            "#{stop.name} - #{stop_id}"
          end

        stop ->
          if unique_stop_info?(state[mode], state[mode][stop_id]) do
            "#{stop.name} (#{stop.platform_name})"
          else
            "#{stop.name} (#{stop.platform_name}) - #{stop_id}"
          end
      end

    {:reply, stop_name, state}
  end

  def handle_call({:get_stop_name, _mode, stop_id}, _from, state) do
    {:reply, stop_id, state}
  end

  def handle_info(:load_stop_data, _state) do
    {:noreply, %{subway: load_stop_data(:subway), commuter_rail: load_stop_data(:commuter_rail)}}
  end

  @spec load_stop_data(PredictionAnalyzer.Utilities.mode()) :: %{String.t() => stop_info()}
  defp load_stop_data(mode) do
    path = "stops"
    params = get_params(mode)

    case PredictionAnalyzer.Utilities.APIv3.request(path, params: params) do
      {:ok, response} ->
        parse_response(response)

      {:error, e} ->
        Logger.warn("Could not download stop names; received: #{inspect(e)}")
        %{}
    end
  end

  @spec get_params(PredictionAnalyzer.Utilities.mode()) :: %{String.t() => String.t()}
  defp get_params(:subway), do: %{"filter[route_type]" => "0,1"}
  defp get_params(:commuter_rail), do: %{"filter[route_type]" => "2"}

  @spec parse_response(%HTTPoison.Response{}) :: %{String.t() => stop_info()}
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

  @spec unique_stop_info?(%{String.t() => stop_info()}, stop_info()) :: boolean()
  defp unique_stop_info?(mode_state, stop_info) do
    mode_state
    |> Map.values()
    |> do_unique_stop_id?(stop_info, false)
  end

  @spec do_unique_stop_id?([stop_info()], stop_info(), boolean()) :: boolean()
  defp do_unique_stop_id?([], _, _), do: true
  defp do_unique_stop_id?([stop_info | _], stop_info, true), do: false

  defp do_unique_stop_id?([stop_info | stop_infos], stop_info, false) do
    do_unique_stop_id?(stop_infos, stop_info, true)
  end

  defp do_unique_stop_id?([_ | stop_infos], stop_info, seen?) do
    do_unique_stop_id?(stop_infos, stop_info, seen?)
  end
end
