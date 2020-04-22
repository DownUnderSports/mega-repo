use Mix.Config

# Configure your database
config :down_under_sports, DownUnderSports.Repo,
  username: "postgres",
  password: "postgres",
  database: "down_under_sports_test",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :down_under_sports, DownUnderSportsWeb.Endpoint,
  http: [port: 4002],
  server: false

# Print only warnings and errors during test
config :logger, level: :warn
