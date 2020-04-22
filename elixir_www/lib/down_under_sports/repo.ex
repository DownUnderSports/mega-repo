defmodule DownUnderSports.Repo do
  use Ecto.Repo,
    otp_app: :down_under_sports,
    adapter: Ecto.Adapters.Postgres
end
