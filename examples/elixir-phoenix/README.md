# Elixir Phoenix Remote Debugging Example

Remote debugging example for Elixir Phoenix applications running in Kubernetes pods.

## Overview

This example demonstrates remote debugging of Elixir Phoenix applications running in Kubernetes using the **VS Code Remote - Kubernetes** extension.

**Language:** Elixir (v1.18)
**Framework:** Phoenix
**Debug Method:** ElixirLS DAP running inside the Kubernetes pod (via Remote - Kubernetes extension)

### ✅ Working Solution: Remote - Kubernetes Extension

The recommended approach uses the [Remote - Kubernetes](https://marketplace.visualstudio.com/items?itemName=okteto.remote-kubernetes) VS Code extension (by Okteto) to run ElixirLS **inside** the pod. This avoids distributed Erlang complexity and works reliably.

**How it works:**
1. VS Code connects to the pod via SSH
2. ElixirLS runs inside the pod (same environment as the app)
3. Full debugging support: breakpoints, stepping, variable inspection
4. Proper module interpretation with memory-optimized configuration

### Alternative Approaches (Not Recommended)

- ❌ **ElixirLS Remote Attach** - Doesn't work due to Erlang `:int` module limitations (modules already loaded)
- ❌ **IEx.pry** - Requires interactive TTY, incompatible with containers
- ✅ **Manual In-Pod Debugging** - Works but lacks VS Code integration (see Approach 2 below)

## Prerequisites

- Kubernetes cluster (local or remote)
- kubectl configured and connected
- Docker for building images
- VS Code with extensions:
  - [Kubernetes](https://marketplace.visualstudio.com/items?itemName=ms-kubernetes-tools.vscode-kubernetes-tools) (for cluster browsing and "Attach to Pod" command)
  - [Remote - Kubernetes](https://marketplace.visualstudio.com/items?itemName=okteto.remote-kubernetes) (by Okteto)
  - [ElixirLS](https://marketplace.visualstudio.com/items?itemName=JakeBecker.elixir-ls) (will be auto-recommended when connecting)

## Quick Start

```bash
# Set your developer namespace and registry
export NAMESPACE=dev-yourname
export REGISTRY=your-registry.azurecr.io  # Replace with your container registry (Docker Hub, GCR, etc.)

# Build the Docker image
./manage.sh build

# Push to registry
./manage.sh push

# Deploy to Kubernetes
./manage.sh deploy

# Check status
./manage.sh status
```

## Project Structure

```
elixir-phoenix/
├── lib/
│   ├── elixir_phoenix/
│   │   └── application.ex          # Application supervisor
│   ├── elixir_phoenix_web/
│   │   ├── controllers/
│   │   │   ├── api_controller.ex   # Sample API endpoints
│   │   │   └── error_json.ex       # Error handling
│   │   ├── endpoint.ex              # Phoenix endpoint
│   │   ├── router.ex                # Routes definition
│   │   └── telemetry.ex             # Telemetry setup
│   ├── elixir_phoenix.ex
│   └── elixir_phoenix_web.ex
├── config/                          # Phoenix configuration
├── k8s/                             # Kubernetes manifests
│   ├── deployment.yaml              # Deployment with debug config
│   ├── service.yaml                 # Service definition
│   └── secret.yaml                  # Erlang cookie secret
├── Dockerfile                       # Elixir image with distributed Erlang
├── .dockerignore                    # Docker ignore patterns
├── mix.exs                          # Mix project configuration
├── manage.sh                        # Example management script
├── PLANNING.md                      # Implementation planning document
└── README.md                        # This file
```

## Building the Docker Image

```bash
# Build image (default tag: latest)
./manage.sh build

# Build with custom tag (optional - must use same tag for push/deploy)
./manage.sh -t v1.0.0 build
./manage.sh -t v1.0.0 push
./manage.sh -t v1.0.0 deploy
```

### Docker Configuration

The Dockerfile supports two debugging approaches:

1. **Remote - Kubernetes** (primary): ElixirLS runs inside the pod
   - SSH server for VS Code connection
   - Development tools (bash, curl, git)
   - Embedded `.vscode-remote/launch.json` with memory-optimized config

2. **Manual In-Pod** (fallback): Direct IEx debugging
   - Distributed Erlang enabled (`--name`, `--cookie`)
   - EPMD and distribution ports exposed
   - Allows `kubectl exec` with IEx remote shell

```dockerfile
# SSH for Remote - Kubernetes
RUN apk add --no-cache openssh bash curl git

# VS Code config embedded in image
COPY .vscode-remote /app/.vscode-remote

# Start IEx (distributed Erlang optional, used for manual debugging)
CMD iex --name ${RELEASE_NODE} --cookie ${RELEASE_COOKIE} -S mix
```

**Note:** Distributed Erlang flags are optional for Remote - Kubernetes but enable the manual debugging fallback method.

## Deploying to Kubernetes

### Deploy to Your Namespace

```bash
# Set namespace (if not already set)
export NAMESPACE=dev-yourname

# Create namespace (first time only)
kubectl create namespace $NAMESPACE

# Deploy (creates Secret, Deployment, and Service)
./manage.sh deploy

# Check deployment status
./manage.sh status

# View logs
./manage.sh logs --follow

# Or use -n flag to override NAMESPACE env var
./manage.sh -n other-namespace deploy
```

## Remote Debugging Workflows

### Approach 1: VS Code Remote - Kubernetes (Recommended)

This approach provides full VS Code integration with breakpoints, variable inspection, and step debugging by running ElixirLS directly inside the pod.

#### Step-by-Step Debugging Session

**Step 1: Deploy to Kubernetes**
```bash
export NAMESPACE=dev-yourname
./manage.sh deploy
./manage.sh status  # Wait for pod to be Running
```

**Step 2: Install Remote - Kubernetes extension**
- Open VS Code
- Install extension: `okteto.remote-kubernetes`

**Step 3: Connect to the pod**

Option A - Via Kubernetes sidebar (easiest):
- Open Kubernetes view in VS Code sidebar
- Expand your cluster → Workloads → Pods
- Right-click on `elixir-phoenix-*` pod
- Select **"Attach Visual Studio Code"**
- VS Code will reload and connect to the pod via SSH

Option B - Via Command Palette:
- Open Command Palette (`Cmd+Shift+P` / `Ctrl+Shift+P`)
- Run: `Dev Containers: Attach to Running Kubernetes Container...`
- Select your namespace and the `elixir-phoenix-*` pod
- Select container: `elixir-phoenix`

**Step 4: Install ElixirLS in the remote session**
- VS Code will prompt to install recommended extensions
- Click "Install" for ElixirLS extension
- Wait for ElixirLS to compile and start

**Step 5: Open the app directory**
- In the remote VS Code window, open folder: `/app`
- ElixirLS will automatically load the `.vscode-remote/launch.json` configuration

**Step 6: Set breakpoints**
- Open `lib/elixir_phoenix_web/controllers/api_controller.ex`
- Click in the gutter to set a breakpoint (e.g., line 17)

**Step 7: Start debugging**
- Open Run and Debug panel (`Cmd+Shift+D` / `Ctrl+Shift+D`)
- Select "mix phx.server" configuration
- Press F5 to start debugging
- Phoenix will compile and start with debugging enabled

**Step 8: Trigger your endpoint**
```bash
# In a local terminal (not in the remote session)
./manage.sh port-forward

# Make a request
curl http://localhost:4000/debug-test?count=3
```

**Step 9: Debug in VS Code**
- Execution pauses at your breakpoint
- Inspect variables in VS Code Variables panel
- Use step controls (F10=step over, F11=step into, F5=continue)

#### Configuration Details

The `.vscode-remote/launch.json` is embedded in the Docker image:

```json
{
  "type": "mix_task",
  "name": "mix phx.server",
  "request": "launch",
  "task": "phx.server",
  "projectDir": "${workspaceRoot}",
  "debugAutoInterpretAllModules": false,
  "debugInterpretModulesPatterns": [
    "^Elixir\\.ElixirPhoenixWeb\\.ApiController$"
  ],
  "excludeModules": [
    "^Elixir\\.Phoenix\\..*",
    "^Elixir\\.Plug\\..*",
    "^Elixir\\.Bandit\\..*",
    // ... other framework modules
  ],
  "requireFiles": [
    "lib/elixir_phoenix_web/controllers/api_controller.ex"
  ],
  "exitAfterTaskReturns": false
}
```

**Key configuration options:**

- `debugAutoInterpretAllModules: false` - Don't interpret all modules (memory optimization)
- `debugInterpretModulesPatterns` - Only interpret specific modules you want to debug
- `excludeModules` - Explicitly exclude framework modules (Phoenix, Plug, Bandit, etc.)
- `exitAfterTaskReturns: false` - Keep debugger running after Phoenix starts

**Memory Optimization:**

By default, ElixirLS interprets **all modules** in your application (300+ including frameworks), which causes OOM errors. The configuration above limits interpretation to only the modules you need to debug.

To add more modules for debugging, update the pattern:
```json
"debugInterpretModulesPatterns": [
  "^Elixir\\.ElixirPhoenixWeb\\.ApiController$",
  "^Elixir\\.ElixirPhoenixWeb\\.YourOtherController$"
]
```

#### Important Notes

- **Memory allocation**: Pod has 2Gi memory limit to handle ElixirLS overhead
- **First connection**: Takes longer as ElixirLS compiles the project
- **Subsequent connections**: Faster (ElixirLS cache persists in pod)
- **Pod restarts**: Reconnect using "Attach Visual Studio Code to Pod" again
- **Known warnings**: ElixirLS may show "undefined variable" errors in debug console - these are harmless inspection artifacts

---

### Approach 2: Manual In-Pod Debugging

This approach works when VS Code integration isn't needed or when you want debugging in a production-like environment.

#### How It Works

1. Phoenix app runs as named Erlang node with distributed Erlang enabled
2. Exec into the running pod
3. Recompile code with debug info (`--debug-info`)
4. Connect to the running node and use `:int` module to set breakpoints
5. Step through code and view output via `IO.inspect()` in logs

### Complete Debugging Session

**Step 1: Exec into the pod**
```bash
# Get pod name
kubectl get pods -n <namespace> -l app=elixir-phoenix

# Exec into pod
kubectl exec -it -n <namespace> <pod-name> -- /bin/sh
```

**Step 2: Get the Erlang cookie**
```bash
echo $RELEASE_COOKIE
```

**Step 3: Recompile with debug info**
```bash
cd /app
MIX_ENV=dev mix compile --force --debug-info
```

**Step 4: Connect to the running Elixir node**
```bash
iex --name debugger@127.0.0.1 --cookie <cookie-from-step-2> --remsh elixir_phoenix@127.0.0.1
```

**Step 5: Set up debugging in IEx**
```elixir
# Start debugger application
Application.ensure_all_started(:debugger)

# Interpret the module (make it debuggable)
:int.ni(ElixirPhoenixWeb.ApiController)

# Set breakpoint at line 30
:int.break(ElixirPhoenixWeb.ApiController, 30)

# Verify breakpoint is set
:int.all_breaks()
```

**Step 6: Trigger the endpoint** (in another terminal)
```bash
kubectl port-forward -n <namespace> svc/elixir-phoenix 4000:4000
curl http://localhost:4000/debug-test
```

**Step 7: Check if breakpoint was hit**
```elixir
:int.snapshot()
# You should see a process with status :break
```

**Step 8: Step through code**
```elixir
# Helper to see current line
current_line = fn ->
  case :int.snapshot() |> Enum.find(fn {_, _, s, _} -> s == :break end) do
    {_pid, _mfa, :break, {_mod, line}} -> "Line #{line}"
    _ -> "Not stopped"
  end
end

# Get the stopped process
{pid, _, _, _} = :int.snapshot() |> Enum.find(fn {_, _, status, _} -> status == :break end)

# Step to next line
:int.step(pid)
current_line.()  # Shows current line number

# Step again
:int.step(pid)
current_line.()

# Continue execution
:int.continue(pid)
```

**Step 9: View variable values**

Since direct variable inspection requires the GUI debugger, use `IO.inspect()` in your code:

```elixir
def debug_test(conn, params) do
  count = parse_count(params)
  IO.inspect(count, label: "Count")  # Output appears in logs
  IO.inspect(params, label: "Params")
  # ...
end
```

Watch logs in another terminal:
```bash
./manage.sh logs --follow
```

## Sample API Endpoints

```bash
# Port-forward first
./manage.sh port-forward

# Health check
curl http://localhost:4000/health

# Debug test endpoint (good for testing breakpoints)
curl http://localhost:4000/debug-test

# Weather forecast
curl http://localhost:4000/weatherforecast
```

## Debugging Capabilities Summary

### Remote - Kubernetes Approach (Approach 1)
✅ **What Works:**
- Full VS Code integration with breakpoints
- Pause execution when code hits breakpoints
- Step through code (F10=over, F11=into, F5=continue)
- Inspect variables in VS Code Variables panel
- Evaluate expressions in Debug Console
- Call stack navigation
- Works with minimal memory when properly configured

⚠️ **Known Issues:**
- ElixirLS shows harmless "undefined variable" warnings in debug console
- First connection is slow (ElixirLS compiles project)
- Default configuration causes OOM (must use optimized config)

### Manual In-Pod Debugging (Approach 2)
✅ **What Works:**
- Set breakpoints at specific line numbers
- Pause execution when code hits breakpoints
- Step through code line by line (`:int.step/1`)
- See current line number while stepping
- View variable values via `IO.inspect()` in logs
- Continue execution (`:int.continue/1`)

❌ **Limitations:**
- No VS Code integration
- No direct variable inspection (requires `IO.inspect()`)
- Manual command-line workflow

## Why Other Approaches Don't Work

❌ **ElixirLS Remote Attach (Distributed Erlang):**
The `:int` module can only interpret modules **before** they are loaded. Once Phoenix starts, all modules are already loaded and cannot be interpreted remotely without restarting the app. ElixirLS connects but can't interpret modules on the remote node.

❌ **IEx.pry:**
Requires an interactive IEx session with proper TTY from startup, which is incompatible with containerized environments where stdin/stdout are redirected.

## Troubleshooting

### Pod OOMKilled / Memory Issues

**Symptom:** Pod restarts with exit code 137

**Cause:** ElixirLS interpreting too many modules (default behavior)

**Solution:** Ensure `.vscode-remote/launch.json` has proper configuration:
```json
{
  "debugAutoInterpretAllModules": false,
  "debugInterpretModulesPatterns": [
    "^Elixir\\.ElixirPhoenixWeb\\.YourModule$"
  ],
  "excludeModules": [
    "^Elixir\\.Phoenix\\..*",
    "^Elixir\\.Plug\\..*",
    "^Elixir\\.Bandit\\..*"
    // Add other framework modules
  ]
}
```

Check memory usage:
```bash
kubectl top pod -n <namespace>
```

### Remote - Kubernetes Connection Issues

**Symptom:** "Failed to connect to pod"

**Solutions:**
1. Verify pod is running: `kubectl get pods -n <namespace> -l app=elixir-phoenix`
2. Check SSH is enabled in Dockerfile
3. Ensure Remote - Kubernetes extension is installed
4. Try reconnecting: `Kubernetes: Attach Visual Studio Code to Pod`

### ElixirLS Not Starting

**Symptom:** ElixirLS shows errors or doesn't load

**Solutions:**
1. Wait for ElixirLS to finish compiling (check status bar)
2. Reload VS Code window: `Developer: Reload Window`
3. Check ElixirLS output: View → Output → ElixirLS

### Breakpoint Not Hit

**For Remote - Kubernetes approach:**
1. Verify breakpoint has red dot (not gray) - module must be interpreted
2. Check module is in `debugInterpretModulesPatterns`
3. Ensure Phoenix is running (started via F5)
4. Verify you're hitting the correct endpoint

**For Manual In-Pod approach:**
1. Verify module is interpreted: `:int.interpreted()`
2. Check breakpoint is set: `:int.all_breaks()`
3. Ensure you're triggering the correct endpoint
4. Check if process exited before hitting breakpoint: `:int.snapshot()`

### Module Interpretation Fails (Manual approach)

```elixir
:int.ni(ElixirPhoenixWeb.ApiController)
# Returns: :error

# Solution: Recompile with debug info
cd /app
MIX_ENV=dev mix compile --force --debug-info
```

### Performance is Slow

Module interpretation is 10-100x slower. This is normal for interpreted code. Only interpret modules you need to debug.

For Remote - Kubernetes: Limit `debugInterpretModulesPatterns` to minimal set of modules.

## Security Considerations

⚠️ **Development only configuration**

- Erlang cookie is a shared secret - never commit real cookies
- Distribution ports allow full node access - only expose via port-forward
- Recompiling code inside production pods is not recommended
- For production debugging, use `:observer`, `:recon`, or telemetry instead

## Additional Resources

- [Erlang `:int` module documentation](https://www.erlang.org/doc/apps/debugger/int.html)
- [Erlang Debugger Guide](https://www.erlang.org/doc/apps/debugger/debugger_chapter.html)
- [Erlang Distribution Protocol](https://www.erlang.org/doc/apps/erts/erl_dist_protocol.html)
- [Phoenix Deployment Guides](https://hexdocs.pm/phoenix/deployment.html)
- [PLANNING.md](./PLANNING.md) - Details of debugging approaches attempted

## Related Examples

- [nodejs-express](../nodejs-express/)
- [python-fastapi](../python-fastapi/)
- [go-gin](../go-gin/)
- [java-spring-boot](../java-spring-boot/)
- [rust-actix-web](../rust-actix-web/)
