# Pre-interpret modules before Phoenix starts
# This ensures modules are interpreted BEFORE they're loaded
IO.puts("=== Pre-interpreting modules for debugging ===")

# Start debugger
Application.ensure_all_started(:debugger)

# Interpret the modules we want to debug
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
IO.puts("=== Waiting for Phoenix to start (via manage.sh start-phoenix) ===")
