defmodule Predictions.ReleaseTasks do
  @moduledoc "Tasks that need to be run on app startup"

  alias PredictionAnalyzer.Repo
  alias Ecto.Migrator

  def migrate do
    migrations_path = Application.app_dir(:prediction_analyzer, "priv/repo/migrations")
    Migrator.run(Repo, migrations_path, :up, all: true)
  end
end

defmodule Predictions.ReleaseTasks.NoOp do
  @moduledoc "Don't do any migrations on non-prod application starts"

  def migrate, do: nil
end
