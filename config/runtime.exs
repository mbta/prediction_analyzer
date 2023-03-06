import Config

is_prod? = config_env() == :prod

if is_prod? do
  sentry_env = System.fetch_env!("SENTRY_ENV")

  config :sentry,
    dsn: System.fetch_env!("SENTRY_DSN"),
    environment_name: sentry_env,
    enable_source_code_context: true,
    root_source_code_path: File.cwd!(),
    tags: %{
      env: sentry_env
    },
    included_environments: [sentry_env]
end
