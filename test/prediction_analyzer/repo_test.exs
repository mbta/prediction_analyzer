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

      config =
        [username: "u", hostname: "h", port: 4000]
        |> PredictionAnalyzer.Repo.before_connect()

      assert {:ok, "iam_token"} = Keyword.fetch(config, :password)
    end

    test "enables TLS/SSL encryption" do
      reassign_env(:aws_rds_mod, FakeAwsRds)

      config =
        [username: "u", hostname: "h", port: 4000]
        |> PredictionAnalyzer.Repo.before_connect()

      certfile_path = config[:ssl][:cacertfile]
      assert certfile_path
      assert Path.basename(certfile_path) == "aws-cert-bundle.pem"
    end
  end
end
