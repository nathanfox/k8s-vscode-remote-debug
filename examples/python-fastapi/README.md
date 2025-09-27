# Python FastAPI Remote Debugging Example

Remote debugging example for Python FastAPI applications running in Kubernetes pods.

## Overview

This example demonstrates how to:
- Build a Docker image with debugpy enabled
- Deploy to Kubernetes with debug port exposed
- Port-forward debug port (5678) from local machine to remote pod
- Attach VS Code debugger using debugpy
- Set breakpoints, inspect variables, and step through async code

**Language:** Python (v3.12)
**Framework:** FastAPI
**Debugger:** debugpy
**Debug Method:** Port-forward to debug port 5678

## Prerequisites

- Kubernetes cluster (local or remote)
- kubectl configured and connected
- Docker for building images
- VS Code with extensions:
  - Python (ms-python.python)
  - Debugpy (ms-python.debugpy)
  - Kubernetes (ms-kubernetes-tools.vscode-kubernetes-tools)
- Python 3.10+ (for local development)

## Quick Start

```bash
# Set your developer namespace
export NAMESPACE=dev-yourname
export REGISTRY=your-registry.azurecr.io

# Build the Docker image
./manage.sh build

# Push to registry
./manage.sh push

# Deploy to Kubernetes
./manage.sh deploy

# Port-forward debug port and attach VS Code debugger
./manage.sh debug

# In VS Code, press F5 to attach debugger
```

## Project Structure

```
python-fastapi/
├── src/
│   └── main.py                  # FastAPI application
├── k8s/                         # Kubernetes manifests
│   ├── deployment.yaml          # Deployment with debug config
│   └── service.yaml             # Service definition
├── .vscode/                     # VS Code configuration
│   ├── launch.json             # Debug configuration (attach via port 5678)
│   ├── tasks.json              # Build/deploy tasks
│   └── extensions.json         # Recommended extensions
├── Dockerfile                   # Python image with debugpy
├── .dockerignore               # Docker ignore patterns
├── requirements.txt             # Python dependencies
├── manage.sh                    # Example management script
└── README.md                    # This file
```

## Building the Docker Image

```bash
# Build debug image (with debugpy)
./manage.sh build

# Build with custom tag
./manage.sh -t v1.0.0 build
```

### Docker Configuration

The Dockerfile installs debugpy and the application is configured to start it:

```python
import debugpy

DEBUG_PORT = int(os.getenv("DEBUG_PORT", "5678"))
ENABLE_DEBUGPY = os.getenv("ENABLE_DEBUGPY", "true").lower() == "true"

if ENABLE_DEBUGPY:
    debugpy.listen(("0.0.0.0", DEBUG_PORT))
```

**Important:** Unlike Node.js (which uses `--inspect` flag) or .NET (which uses vsdbg), Python debugging with debugpy **requires code changes**. You must:
1. Import debugpy in your application code
2. Call `debugpy.listen()` to start the debug server
3. Use `ENABLE_DEBUGPY` environment variable to conditionally enable debugging

This approach:
- Enables debugpy on application startup when `ENABLE_DEBUGPY=true`
- Listens on all interfaces (0.0.0.0)
- Uses port 5678 (debugpy default)
- Allows remote debuggers to connect
- Can be disabled in production by setting `ENABLE_DEBUGPY=false`

**Best Practice:** Always use the conditional check with `ENABLE_DEBUGPY` so you can deploy the same Docker image to both debug and production environments by changing only the environment variable.

## Deploying to Kubernetes

### Deploy to Your Namespace

```bash
# Create namespace (first time only)
../../manage.sh create-ns -n dev-yourname

# Deploy the example
./manage.sh -n dev-yourname deploy
```

Or use environment variable:

```bash
export NAMESPACE=dev-yourname
./manage.sh deploy
```

### Verify Deployment

```bash
# Check pod status
./manage.sh status

# View logs
./manage.sh logs

# Follow logs
./manage.sh logs --follow
```

## Setting Up Remote Debugging

### Step 1: Deploy and Verify Pod is Ready

```bash
./manage.sh deploy
./manage.sh status
```

### Step 2: Port-Forward Debug Port

debugpy requires port-forwarding port 5678:

```bash
# Port-forward debug port (runs in foreground)
./manage.sh debug

# Or run in background
./manage.sh port-forward-debug &
```

**What this does:**
- Forwards local port 5678 → pod port 5678
- VS Code debugger connects to localhost:5678
- debugpy handles debugging protocol

### Step 3: Attach VS Code Debugger

```bash
# Open this example in VS Code
code .
```

1. Ensure port-forward is running (`./manage.sh debug`)
2. Open the "Run and Debug" panel (Ctrl+Shift+D / Cmd+Shift+D)
3. Select **"Attach to Remote Pod"** from the dropdown
4. Press **F5** or click the green play button

**What happens:**
- VS Code connects to localhost:5678
- debugpy accepts connection
- Debugger attaches to running Python process
- You can now set breakpoints and debug!

## Debugging Walkthrough

### Test the Application

```bash
# In a separate terminal, port-forward the application
./manage.sh port-forward

# Make requests
curl http://localhost:8080/health
curl http://localhost:8080/debug-test?count=5
curl http://localhost:8080/weatherforecast
```

### Debug Session Example

1. **Set a breakpoint** in `src/main.py` at line 28 (inside the `/debug-test` handler)
2. **Start port-forward**: `./manage.sh debug` (in separate terminal)
3. **Attach debugger** (F5 in VS Code)
4. **Make a request**: `curl http://localhost:8080/debug-test?count=3`
5. **Breakpoint hits** - execution pauses at line 28
6. **Inspect variables**:
   - Hover over `count` - shows the value (3)
   - Check Variables panel - see `items`, `i`
   - Inspect async context
7. **Step through code**:
   - F10 (step over) - executes current line
   - F11 (step into) - step into async functions
   - Watch the `items` list grow as you step through the loop
8. **Continue execution** - F5 to resume

### What You Can Debug

- ✅ Breakpoints in Python files
- ✅ Variable inspection (primitives, objects, lists, dicts)
- ✅ Call stack navigation (including async call stacks)
- ✅ Conditional breakpoints
- ✅ Expression evaluation in Debug Console
- ✅ Watch expressions
- ✅ Exception breakpoints
- ✅ Async/await debugging
- ✅ Coroutine inspection

### Python-Specific Debugging Features

**Async/Await Debugging:**
- Full async call stack visible
- Can pause in async functions
- Coroutine states inspectable
- Unhandled exception detection

**Performance:**
- Fast attach/detach
- Hot reload with uvicorn --reload (dev mode)
- Can profile async operations

**Tips for Debugging Python:**
- Use `breakpoint()` built-in for programmatic breakpoints
- Enable "Pause on caught exceptions" for error tracking
- Use Debug Console to evaluate expressions in current context
- Inspect `os.environ` to view environment variables
- Set `justMyCode: false` to step into library code

## Application Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Health check (returns status and timestamp) |
| `/debug-test?count=N` | GET | Async endpoint for debugging (creates N items with delays) |
| `/weatherforecast` | GET | Weather forecast (5-day sample data) |

## FastAPI Framework Notes

**FastAPI** is a modern Python web framework:
- Built on Starlette and Pydantic
- Async-first design (async/await native)
- Automatic OpenAPI documentation
- Type hints for validation
- Query parameter parsing via function parameters

Example async route handler:
```python
@app.get("/debug-test")
async def debug_test(count: int = Query(default=3, ge=1, le=20)):
    items = []

    for i in range(count):
        items.append(f"Item {i + 1}")
        await asyncio.sleep(0.01)

    return {
        "count": count,
        "items": items,
        "timestamp": datetime.utcnow().isoformat()
    }
```

## VS Code Extensions

Recommended extensions (auto-suggested when opening this folder):

- **Python** (ms-python.python) - Python language support
- **Debugpy** (ms-python.debugpy) - Python debugging
- **Kubernetes** (ms-kubernetes-tools.vscode-kubernetes-tools) - K8s management

## Management Commands

```bash
# Build debug image
./manage.sh build

# Push to registry
./manage.sh push

# Deploy to namespace
./manage.sh -n NAMESPACE deploy

# Port-forward debug port (5678) and attach debugger
./manage.sh -n NAMESPACE debug

# Port-forward application port
./manage.sh -n NAMESPACE port-forward

# View logs
./manage.sh -n NAMESPACE logs [--follow]

# Execute shell in pod
./manage.sh -n NAMESPACE shell

# Restart deployment
./manage.sh -n NAMESPACE restart

# Delete from namespace
./manage.sh -n NAMESPACE delete

# Show status
./manage.sh -n NAMESPACE status

# Show help
./manage.sh help
```

## Troubleshooting

### Debugger Won't Connect

**Symptom:** VS Code shows "Cannot connect to runtime process" or timeout

**Solutions:**

1. **Verify port-forward is running:**
   ```bash
   # Should show kubectl port-forward process
   ps aux | grep "port-forward.*5678"
   ```

2. **Check pod is running:**
   ```bash
   ./manage.sh status
   # Pod should show "Running"
   ```

3. **Verify debugpy is listening on 5678:**
   ```bash
   ./manage.sh logs
   # Should show "debugpy listening on 0.0.0.0:5678"
   ```

4. **Restart port-forward:**
   ```bash
   # Kill existing port-forward
   pkill -f "port-forward.*5678"

   # Start new port-forward
   ./manage.sh debug
   ```

### Breakpoints Not Hitting

**Symptom:** Breakpoints show as grey/hollow circles

**Solutions:**

1. **Ensure source paths match:**
   - Check `.vscode/launch.json` pathMappings
   - localRoot: `${workspaceFolder}/src`
   - remoteRoot: `/app/src`

2. **Verify files are mounted correctly:**
   ```bash
   ./manage.sh shell
   ls -la /app/src
   # Should show main.py
   ```

3. **Check debugpy is attached:**
   - VS Code should show "Python: Attached" in status bar
   - Debug Console should show connection message

4. **Restart debugging session:**
   - Stop debugger (Shift+F5)
   - Restart port-forward
   - Attach again (F5)

### Pod Crashes on Startup

**Symptom:** Pod status shows `CrashLoopBackOff`

**Solutions:**

```bash
# Check logs
./manage.sh logs

# Common issues:
# - Missing dependencies (check requirements.txt)
# - Syntax errors in Python
# - Port conflicts
# - Import errors
```

### Port-Forward Connection Drops

**Symptom:** Debugger disconnects randomly

**Solutions:**

- **Network timeouts**: kubectl port-forward can timeout on idle connections
- **Workaround**: Set longer timeouts or restart port-forward when needed
- **Alternative**: Use `kubectl port-forward svc/python-fastapi 5678:5678` for service-level forwarding

### Common Issues

**Issue:** "Address already in use: 5678"
**Solution:** Another process is using port 5678 locally. Kill it: `lsof -ti:5678 | xargs kill`

**Issue:** Debugger connects but breakpoints don't pause execution
**Solution:** Ensure `ENABLE_DEBUGPY=true` environment variable is set

**Issue:** Can't see async call stacks
**Solution:** debugpy shows async stacks by default in recent versions

## Configuration Details

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `PYTHONUNBUFFERED` | Disable Python output buffering | `1` |
| `ENABLE_DEBUGPY` | Enable debugpy on startup | `true` |
| `DEBUG_PORT` | debugpy listen port | `5678` |

### Kubernetes Labels

The deployment uses these labels:
```yaml
app: python-fastapi
framework: fastapi
language: python
version: "3.12"
debug-enabled: "true"
```

## VS Code Debug Configuration

The `.vscode/launch.json` uses standard Python attach configuration:

```json
{
  "name": "Attach to Remote Pod",
  "type": "debugpy",
  "request": "attach",
  "connect": {
    "host": "localhost",
    "port": 5678
  },
  "pathMappings": [
    {
      "localRoot": "${workspaceFolder}/src",
      "remoteRoot": "/app/src"
    }
  ],
  "justMyCode": false
}
```

This method:
- Connects to debugpy on localhost:5678
- Requires port-forward to be running
- Maps local source files to remote paths
- `justMyCode: false` allows stepping into libraries

## Difference from Other Language Debugging

Python debugging with debugpy has some unique characteristics compared to other languages:

### vs .NET (C#/F#)
- **.NET:** No code changes needed, vsdbg installed in image, uses `kubectl exec` with pipeTransport
- **Python:** Requires `import debugpy` and `debugpy.listen()` in application code
- **Python:** Uses port-forwarding to debug port 5678 (TCP-based like Node.js)
- **Python:** Can be conditionally enabled via `ENABLE_DEBUGPY` environment variable

### vs Node.js
- **Node.js:** No code changes needed, enabled via `--inspect` command-line flag
- **Python:** Requires explicit debugpy import and initialization in code
- **Both:** Use port-forwarding for debugging (Node.js: 9229, Python: 5678)
- **Both:** TCP-based debug protocol, require separate port-forward process

### Summary Table

| Language | Code Changes | Debug Method | Port | Conditional |
|----------|--------------|--------------|------|-------------|
| .NET | ❌ None | kubectl exec | N/A | Image-level |
| Node.js | ❌ None | Port-forward | 9229 | CLI flag |
| Python | ✅ Required | Port-forward | 5678 | Env var |

**Python's approach** requires code changes but offers flexibility through environment variables, allowing the same codebase to work in both debug and production environments.

## Integration with nginx-dev-gateway

This example works with [nginx-dev-gateway](https://github.com/nathanfox/nginx-dev-gateway):

```bash
# Deploy nginx gateway to your namespace
# (See nginx-dev-gateway documentation)

# Access via gateway
curl http://localhost:8080/python-api/health
```

## Performance Notes

**Debug Mode (debugpy):**
- Minimal performance impact when not attached
- Slight overhead when debugger attached
- Can be used in production (but not recommended)

**Resource Usage:**
- CPU request: 100m, limit: 500m
- Memory request: 128Mi, limit: 512Mi

## Python Debugging Best Practices

1. **Use `breakpoint()`** - built-in function that works with debugpy
2. **Enable async stack traces** - debugpy shows these automatically
3. **Use Debug Console** - evaluate expressions in paused context
4. **Profile async operations** - debugpy supports profiling
5. **Test error paths** - use "Pause on exceptions" to catch errors
6. **Hot reload** - use uvicorn --reload for faster development

## Next Steps

- Try debugging async/await code with step-through
- Set conditional breakpoints on request parameters
- Use Debug Console to modify variables at runtime
- Deploy multiple examples and debug service-to-service calls
- Integrate with nginx-dev-gateway for microservices debugging

## References

- [debugpy Documentation](https://github.com/microsoft/debugpy)
- [VS Code Python Debugging](https://code.visualstudio.com/docs/python/debugging)
- [FastAPI Documentation](https://fastapi.tiangolo.com/)

## Contributing

Found an issue? See [CONTRIBUTING.md](../../CONTRIBUTING.md) for how to report bugs or suggest improvements.