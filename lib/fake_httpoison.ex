defmodule FakeHTTPoison do
  require Logger

  def get!(url) do
    Logger.info("fetched #{url}")
    %{body: "{}"}
  end
end
