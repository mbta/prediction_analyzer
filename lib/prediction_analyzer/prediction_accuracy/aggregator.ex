defmodule PredictionAnalyzer.PredictionAccuracy.Aggregator do
  use GenServer
  require Logger
  alias PredictionAnalyzer.PredictionAccuracy.Query
  alias PredictionAnalyzer.Filters

  @max_retries 4

  @type t :: %{
          retry_time_fetcher: (integer() -> integer()),
          repo: Ecto.Repo.t()
        }

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, [], opts)
  end

  def init(opts) do
    retry_time_fetcher = opts[:retry_time_fetcher] || fn n -> retry_sleep_ms_per_attempt(n) end
    repo = opts[:repo] || PredictionAnalyzer.Repo
    schedule_next_run(self())
    {:ok, %{retry_time_fetcher: retry_time_fetcher, repo: repo}}
  end

  def handle_info(:aggregate, state) do
    Logger.info("Calculating prediction accuracies")

    {time, result} =
      :timer.tc(fn ->
        timezone = Application.get_env(:prediction_analyzer, :timezone)
        current_time = Timex.now(timezone)
        do_aggregation_with_retries(current_time, state.repo, state.retry_time_fetcher)
      end)

    if result == :ok do
      Logger.info("Finished prediction aggregations in #{time / 1000} ms")
    else
      Logger.warn("Prediction aggregation failed, not retrying")
    end

    schedule_next_run(self())
    {:noreply, state}
  end

  @spec do_aggregation_with_retries(
          DateTime.t(),
          Ecto.Repo.t(),
          (integer() -> integer()),
          integer()
        ) :: :ok | :error
  defp do_aggregation_with_retries(
         current_time,
         repo,
         retry_time_fetcher,
         retries \\ @max_retries
       ) do
    case do_aggregation(current_time, repo) do
      :ok ->
        :ok

      :error ->
        if retries > 0 do
          retry_ms = retry_time_fetcher.(retries)
          Logger.info("Prediction aggregation failed, retrying in #{retry_ms / 1000} seconds")
          Process.sleep(retry_ms)

          do_aggregation_with_retries(current_time, repo, retry_time_fetcher, retries - 1)
        else
          :error
        end
    end
  end

  @spec do_aggregation(DateTime.t(), Ecto.Repo.t()) :: :ok | :error
  defp do_aggregation(current_time, repo) do
    try do
      repo.transaction(
        fn ->
          for environment <- ~w(prod dev-green),
              kind <- [nil | Map.values(Filters.kinds())],
              {bin_name, {bin_min, bin_max, bin_error_min, bin_error_max}} <- Filters.bins(),
              in_next_two? <- [true, false] do
            {:ok, r} =
              Query.calculate_aggregate_accuracy(
                repo,
                current_time,
                kind,
                in_next_two?,
                bin_name,
                bin_min,
                bin_max,
                bin_error_min,
                bin_error_max,
                environment
              )

            Logger.info(
              "prediction_accuracy_aggregator #{environment} #{kind} #{bin_name} result=#{inspect(r)}"
            )
          end
        end,
        timeout: 5 * 60 * 1_000
      )

      :ok
    rescue
      e in DBConnection.ConnectionError ->
        Logger.warn("#{__MODULE__} do_aggregation #{inspect(e)}")
        :error
    end
  end

  defp schedule_next_run(pid) do
    Process.send_after(pid, :aggregate, PredictionAnalyzer.Utilities.ms_to_next_5m())
  end

  @spec retry_sleep_ms_per_attempt(integer()) :: integer()
  def retry_sleep_ms_per_attempt(4), do: 10 * 1_000
  def retry_sleep_ms_per_attempt(3), do: 60 * 1_000
  def retry_sleep_ms_per_attempt(2), do: 600 * 1_000
  def retry_sleep_ms_per_attempt(1), do: 1_800 * 1_000
end
