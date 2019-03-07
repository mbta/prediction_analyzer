defmodule Test.Support.Env do
  defmacro reassign_env(var) do
    quote do
      old_value = Application.get_env(:prediction_analyzer, unquote(var))

      on_exit(fn ->
        Application.put_env(:prediction_analyzer, unquote(var), old_value)
      end)
    end
  end

  defmacro reassign_env(var, value) do
    quote do
      old_value = Application.get_env(:prediction_analyzer, unquote(var))
      Application.put_env(:prediction_analyzer, unquote(var), unquote(value))

      on_exit(fn ->
        Application.put_env(:prediction_analyzer, unquote(var), old_value)
      end)
    end
  end
end
