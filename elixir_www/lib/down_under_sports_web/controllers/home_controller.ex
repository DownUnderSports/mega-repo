defmodule DownUnderSportsWeb.HomeController do
  use DownUnderSportsWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
