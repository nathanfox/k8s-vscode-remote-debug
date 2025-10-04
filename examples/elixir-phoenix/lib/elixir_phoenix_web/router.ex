defmodule ElixirPhoenixWeb.Router do
  use ElixirPhoenixWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", ElixirPhoenixWeb do
    pipe_through :api

    get "/health", ApiController, :health
    get "/debug-test", ApiController, :debug_test
    get "/weatherforecast", ApiController, :weatherforecast
  end
end
