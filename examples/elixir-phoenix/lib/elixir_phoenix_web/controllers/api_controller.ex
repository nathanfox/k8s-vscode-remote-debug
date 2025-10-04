defmodule ElixirPhoenixWeb.ApiController do
  use ElixirPhoenixWeb, :controller

  @moduledoc """
  Simple API controller for demonstrating remote debugging.
  Provides standard endpoints consistent with other language examples.
  """

  def health(conn, _params) do
    json(conn, %{
      status: "healthy",
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    })
  end

  def debug_test(conn, params) do
    IO.puts("=== DEBUG_TEST STARTED ===")

    # Get count from params or default to 3
    count =
      params
      |> Map.get("count", "3")
      |> parse_count()

    IO.puts("Count parsed: #{count}")
    IO.inspect(params, label: "Params")

    # Breakpoint at line 27 - set with :int.break(ElixirPhoenixWeb.ApiController, 27)
    # Generate items array (good place to set a breakpoint!)
    items = generate_items(count)

    IO.puts("Items generated: #{inspect(items)}")

    json(conn, %{
      count: count,
      items: items,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    })
  end

  def weatherforecast(conn, _params) do
    # Generate 5 days of weather forecast (good for stepping through)
    forecasts = generate_forecasts(5)

    json(conn, forecasts)
  end

  # Private functions - good for stepping through with debugger

  defp parse_count(count_str) when is_binary(count_str) do
    case Integer.parse(count_str) do
      {count, _} when count >= 1 and count <= 20 -> count
      _ -> 3
    end
  end
  defp parse_count(_), do: 3

  defp generate_items(count) do
    # Set a breakpoint here to watch the items being generated
    for i <- 1..count do
      # Small delay to simulate processing
      Process.sleep(10)
      "Item #{i}"
    end
  end

  defp generate_forecasts(days) do
    summaries = ["Freezing", "Bracing", "Chilly", "Cool", "Mild", "Warm", "Balmy", "Hot", "Sweltering", "Scorching"]

    # Set a breakpoint here to inspect forecast generation
    for day_offset <- 1..days do
      date = Date.utc_today() |> Date.add(day_offset)
      temp_c = :rand.uniform(76) - 20

      %{
        date: Date.to_iso8601(date),
        temperatureC: temp_c,
        temperatureF: 32 + div(temp_c * 9, 5),
        summary: Enum.random(summaries)
      }
    end
  end
end