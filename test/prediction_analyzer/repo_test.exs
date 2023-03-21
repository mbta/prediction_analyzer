defmodule PredictionAnalyzer.RepoTest do
  use ExUnit.Case, async: false
  import Test.Support.Env

  defmodule FakeAwsRds do
    def generate_db_auth_token(_, _, _, _) do
      "iam_token"
    end
  end

  describe "before_connect/1" do
    test "generates RDS IAM auth token" do
      reassign_env(:aws_rds_mod, FakeAwsRds)
      {:ok, config} = PredictionAnalyzer.Repo.init(nil, [])

      config =
        config
        |> Keyword.merge(username: "u", hostname: "h", port: 4000)
        |> PredictionAnalyzer.Repo.before_connect()

      assert {:ok, "iam_token"} = Keyword.fetch(config, :password)
    end

    test "uses url if present" do
      reassign_env(:aws_rds_mod, FakeAwsRds)
      System.put_env("DATABASE_URL", "test_url")

      {:ok, config} = PredictionAnalyzer.Repo.init(nil, [])

      config =
        config
        |> Keyword.merge(username: "u", hostname: "h", port: 4000)
        |> PredictionAnalyzer.Repo.before_connect()

      assert :error = Keyword.fetch(config, :password)
      assert {:ok, "test_url"} = Keyword.fetch(config, :url)
      System.delete_env("DATABASE_URL")
    end
  end
end
