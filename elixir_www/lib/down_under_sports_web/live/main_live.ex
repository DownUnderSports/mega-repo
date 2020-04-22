defmodule DownUnderSportsWeb.MainLive do
  use Phoenix.LiveView

  def render(assigns) do
    ~L"""
    <div class="thermostat">
      <div class="bar <%= @mode %>">
        <a href="#" phx-click="toggle-mode"><%= @mode %></a>
        <span></span>
      </div>
      <div class="controls">
        <span class="reading"><%= @val %></span>
        <button phx-click="dec" class="minus">-</button>
        <button phx-click="inc" class="plus">+</button>
        <span class="weather">
          <%= live_render(@socket, DownUnderSportsWeb.WeatherLive, id: "weather") %>
        </span>
      </div>
    </div>
    """
  end

  def mount(_session, socket) do
    {:ok, assign(socket, val: 72, mode: :cooling)}
  end

  def handle_event("inc", _, socket) do
    {:noreply, update(socket, :val, &(&1 + 1))}
  end

  def handle_event("dec", _, socket) do
    {:noreply, update(socket, :val, &(&1 - 1))}
  end

  def handle_event("toggle-mode", _, socket) do
    {:noreply,
     update(socket, :mode, fn
       :cooling -> :heating
       :heating -> :cooling
     end)}
  end
end
