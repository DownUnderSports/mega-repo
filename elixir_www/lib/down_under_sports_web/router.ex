defmodule DownUnderSportsWeb.Router do
  use DownUnderSportsWeb, :router
  import Phoenix.LiveView.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug Phoenix.LiveView.Flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", DownUnderSportsWeb do
    pipe_through :browser

    get "/", HomeController, :index
    live "/test", MainLive
  end

  # Other scopes may use custom stacks.
  # scope "/api", DownUnderSportsWeb do
  #   pipe_through :api
  # end
end
