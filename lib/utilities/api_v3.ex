defmodule PredictionAnalyzer.Utilities.APIv3 do
  @default_opts [request_timeout: 2000, receive_timeout: 2000]

  @doc """
  Makes a request to the V3 API and returns the response, if successful.

  Note that Req will automatically JSON-decode the response body, due to the V3 API including the "content-type: application/json` header!
  """
  @spec request(String.t(), %{String.t() => String.t()}, Keyword.t()) ::
          {:error, any()} | {:ok, Req.Response.t()}
  def request(
        path,
        extra_headers \\ %{},
        opts
      ) do
    {env, opts} = Keyword.pop(opts, :env)

    {base_url, api_key_headers} =
      case env do
        :dev_green ->
          {Application.get_env(:prediction_analyzer, :api_dev_green_base_url), %{}}

        _ ->
          {Application.get_env(:prediction_analyzer, :api_base_url),
           api_key_headers(Application.get_env(:prediction_analyzer, :api_v3_key))}
      end

    headers = Map.merge(api_key_headers, extra_headers)

    http_fetcher = Application.get_env(:prediction_analyzer, :http_fetcher)

    opts =
      @default_opts
      |> Keyword.merge(opts)
      |> Keyword.delete(:base_url)
      |> Keyword.put(:headers, headers)

    with {:ok, %{status: 200} = resp} <- http_fetcher.get(base_url <> path, opts) do
      {:ok, resp}
    else
      other -> {:error, other}
    end
  end

  defp api_key_headers(nil), do: %{}
  defp api_key_headers(key), do: %{"x-api-key" => key}
end
