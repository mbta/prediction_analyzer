defmodule PredictionAnalyzer.Utilities.APIv3 do
  @default_opts [timeout: 2000, recv_timeout: 2000]

  @spec request(String.t(), [{String.t(), String.t()}], Keyword.t()) ::
          {:error, any()} | {:ok, map()}
  def request(path, extra_headers \\ [], opts) do
    base_url = Application.get_env(:prediction_analyzer, :api_base_url)

    headers =
      extra_headers ++ api_key_headers(Application.get_env(:prediction_analyzer, :api_v3_key))

    http_fetcher = Application.get_env(:prediction_analyzer, :http_fetcher)

    with {:ok, req} <-
           http_fetcher.get(
             base_url <> path,
             headers,
             Keyword.merge(@default_opts, opts)
           ),
         %{status_code: 200} <- req do
      {:ok, req}
    else
      e -> {:error, e}
    end
  end

  defp api_key_headers(nil), do: []
  defp api_key_headers(key), do: [{"x-api-key", key}]
end
