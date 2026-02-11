defmodule Test.Support.Env do
  def reassign_env(key, value) do
    old_value = Application.get_env(:prediction_analyzer, key)
    Application.put_env(:prediction_analyzer, key, value)

    ExUnit.Callbacks.on_exit(fn ->
      Application.put_env(:prediction_analyzer, key, old_value)
    end)
  end
end
