defmodule Predictions.Utilities.Config do
  def update_env(key, val) do
    if is_nil(Application.get_env(:prediction_analyzer, key)) do
      Application.put_env(:prediction_analyzer, key, val)
    end
  end
end
