# Start script that interprets modules before loading the application
# This allows remote debugging to work with breakpoints

IO.puts("Starting Elixir Phoenix with debug interpretation...")

# Ensure we're in the right directory
File.cd!("/app")

# Add code paths
Mix.start()
Mix.env(:dev)

# Load the project
if File.exists?("mix.exs") do
  Code.require_file("mix.exs")
  Mix.Project.get!()
end

# Ensure code paths are set up
Code.prepend_path("_build/dev/lib/elixir_phoenix/ebin")
Code.prepend_path("_build/dev/lib/phoenix/ebin")
for app <- [:phoenix, :plug, :telemetry] do
  Code.prepend_path("_build/dev/lib/#{app}/ebin")
end

# Start the debugger application
{:ok, _} = Application.ensure_all_started(:debugger)

# List of modules to interpret for debugging (only our app modules)
modules_to_interpret = [
  ElixirPhoenixWeb.ApiController,
  ElixirPhoenixWeb.Router,
  ElixirPhoenixWeb.Endpoint
]

# Interpret each module BEFORE it gets loaded by the application
IO.puts("\nInterpreting modules for debugging:")
Enum.each(modules_to_interpret, fn module ->
  case :int.ni(module) do
    {:module, _} ->
      IO.puts("  ✓ #{inspect(module)}")
    {:error, reason} ->
      IO.puts("  ✗ #{inspect(module)}: #{inspect(reason)}")
    :error ->
      IO.puts("  ✗ #{inspect(module)}: no abstract code")
    other ->
      IO.puts("  ? #{inspect(module)}: #{inspect(other)}")
  end
end)

IO.puts("\nInterpreted modules: #{inspect(:int.interpreted())}")

# Now start the Phoenix application using mix
IO.puts("\nStarting Phoenix server...")
Mix.Task.run("phx.server")

# Keep the process alive
Process.sleep(:infinity)
