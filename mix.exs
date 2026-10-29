defmodule PredictionAnalyzer.Mixfile do
  use Mix.Project

  def project do
    [
      app: :prediction_analyzer,
      version: "0.0.1",
      elixir: "~> 1.9",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: LcovEx],
      dialyzer: [plt_add_apps: [:ex_unit]],
      aliases: aliases(),
      deps: deps()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {PredictionAnalyzer.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_aws_rds, "~> 2.0"},
      {:ecto, "~> 3.14"},
      {:ecto_sql, "~> 3.14"},
      {:lcov_ex, "~> 0.2", only: :test, runtime: false},
      {:gettext, "~> 0.11"},
      # {:hackney, "~> 4.9"},
      # {:httpoison, "~> 3.0"},
      {:req, "~> 0.7.5"},
      {:jason, "~> 1.0"},
      {:oban, "~> 2.19"},
      {:phoenix, "~> 1.6.0"},
      {:phoenix_ecto, "~> 4.7"},
      {:phoenix_html, "~> 3.0"},
      {:phoenix_live_reload, "~> 1.4", only: :dev},
      {:phoenix_pubsub, "~> 2.0"},
      {:plug_cowboy, "~> 2.1"},
      {:plug, "~> 1.10"},
      {:postgrex, ">= 0.0.0"},
      {:timex, "~> 3.7"},
      {:sentry, "~> 14.0"},
      {:csv, "~> 3.0"},
      # provides :ssl_verify_hostname module, used by PredictionAnalyzer.Repo
      {:ssl_verify_fun, "~> 1.1.7"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to create, migrate and run the seeds file at once:
  #
  #     $ mix ecto.setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      "ecto.migrate": ["ecto.migrate", "ecto.dump"],
      "ecto.setup": ["ecto.create", "ecto.load", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      "ecto.rollback": ["ecto.rollback", "ecto.dump"],
      test: [
        "ecto.create --quiet",
        "ecto.load --quiet --skip-if-loaded",
        "ecto.migrate --quiet",
        "test"
      ]
    ]
  end
end
