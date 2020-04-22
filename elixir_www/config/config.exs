# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

config :down_under_sports,
  ecto_repos: [DownUnderSports.Repo]

# Configures the endpoint
config :down_under_sports, DownUnderSportsWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "UkVbrqLZAFrsPfl2CcgnBalZtbtcYOQmQ8dcyM5PBNJjxxl036ev0oBQ5ZIwQkjM",
  render_errors: [view: DownUnderSportsWeb.ErrorView, accepts: ~w(html json)],
  pubsub: [name: DownUnderSports.PubSub, adapter: Phoenix.PubSub.PG2],
  live_view: [
    signing_salt: "nyxnKjumdWpKeW+OeS4kG2RDiw8apMps"
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
