# This script is called to start Phoenix after ElixirLS has attached
# and interpreted the necessary modules for debugging
IO.puts("Starting Phoenix server...")
Mix.Task.run("phx.server")
