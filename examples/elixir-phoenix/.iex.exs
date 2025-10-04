# .iex.exs - runs when IEx starts, BEFORE application loads
IO.puts("=== IEx startup: Pre-interpreting modules ===")

# Start debugger
Application.ensure_all_started(:debugger)

# Interpret modules BEFORE they get loaded
modules_to_interpret = [
  ElixirPhoenixWeb.ApiController
]

Enum.each(modules_to_interpret, fn module ->
  case :int.ni(module) do
    {:module, ^module} ->
      IO.puts("✓ Interpreted: #{inspect(module)}")
    {:error, reason} ->
      IO.puts("✗ Failed to interpret #{inspect(module)}: #{inspect(reason)}")
  end
end)

IO.puts("=== Interpreted modules: #{inspect(:int.interpreted())} ===")
