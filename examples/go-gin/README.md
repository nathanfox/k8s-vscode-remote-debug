# Go Gin Remote Debugging Example

Remote debugging example for Go Gin applications running in Kubernetes pods using Delve.

## Overview

This example demonstrates how to:
- Build a Docker image with Delve debugger enabled
- Deploy to Kubernetes with debug port exposed
- Port-forward debug port (2345) from local machine to remote pod
- Attach VS Code debugger using Delve
- Set breakpoints, inspect variables, and step through Go code

**Language:** Go (v1.23)
**Framework:** Gin
**Debugger:** Delve (dlv)
**Debug Method:** Port-forward to debug port 2345

## Prerequisites

- Kubernetes cluster (local or remote)
- kubectl configured and connected
- Docker for building images
- VS Code with extensions:
  - Go (golang.go)
  - Kubernetes (ms-kubernetes-tools.vscode-kubernetes-tools)
- Go 1.21+ (for local development)

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
go-gin/
├── main.go                      # Go Gin application
├── go.mod                       # Go module definition
├── go.sum                       # Dependency checksums
├── k8s/                         # Kubernetes manifests
│   ├── deployment.yaml          # Deployment with debug config
│   └── service.yaml             # Service definition
├── .vscode/                     # VS Code configuration
│   ├── launch.json             # Debug configuration (attach via port 2345)
│   ├── tasks.json              # Build/deploy tasks
│   └── extensions.json         # Recommended extensions
├── Dockerfile                   # Go image with Delve
├── .dockerignore               # Docker ignore patterns
├── manage.sh                    # Example management script
└── README.md                    # This file
```

## Building the Docker Image

```bash
# Build debug image (with Delve)
./manage.sh build

# Build with custom tag
./manage.sh -t v1.0.0 build
```

### Docker Configuration

The Dockerfile uses a multi-stage build with Delve debugger:

```dockerfile
# Build stage - compile Go app with debug symbols
FROM golang:1.23-alpine AS builder
RUN go build -gcflags="all=-N -l" -o app main.go
RUN go install github.com/go-delve/delve/cmd/dlv@latest

# Runtime stage - run app under Delve
FROM alpine:latest
COPY --from=builder /build/app .
COPY --from=builder /go/bin/dlv /usr/local/bin/dlv
CMD ["/usr/local/bin/dlv", "--listen=:2345", "--headless=true", \
     "--api-version=2", "--accept-multiclient", "exec", "--continue", "/app/app"]
```

**Key configuration:**
- `-gcflags="all=-N -l"`: Disables optimizations and inlining for debugging
- `--listen=:2345`: Delve listens on port 2345
- `--headless=true`: Delve runs in headless mode (no interactive prompt)
- `--api-version=2`: Uses Delve API v2 for VS Code compatibility
- `--accept-multiclient`: Allows multiple debugger connections
- `--continue`: Starts the application immediately (doesn't wait for debugger)

This approach:
- Builds Go binary with debug symbols preserved
- Installs Delve debugger in the image
- Runs application under Delve automatically
- Allows remote debuggers to attach via port 2345
- Application starts immediately and responds to requests

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

Delve requires port-forwarding port 2345:

```bash
# Port-forward debug port (runs in foreground)
./manage.sh debug

# Or run in background
./manage.sh port-forward-debug &
```

**What this does:**
- Forwards local port 2345 → pod port 2345
- VS Code debugger connects to localhost:2345
- Delve handles debugging protocol (DAP)

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
- VS Code connects to localhost:2345
- Delve accepts connection via DAP (Debug Adapter Protocol)
- Debugger attaches to running Go process
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

1. **Set a breakpoint** in `main.go` at line 85 (inside the `/debug-test` handler)
2. **Start port-forward**: `./manage.sh debug` (in separate terminal)
3. **Attach debugger** (F5 in VS Code)
4. **Make a request**: `curl http://localhost:8080/debug-test?count=3`
5. **Breakpoint hits** - execution pauses at line 85
6. **Inspect variables**:
   - Hover over `count` - shows the value (3)
   - Check Variables panel - see `items`, `i`
   - Inspect `c` (Gin context) - view request data
7. **Step through code**:
   - F10 (step over) - executes current line
   - F11 (step into) - step into functions
   - Watch the `items` slice grow as you step through the loop
8. **Continue execution** - F5 to resume

### What You Can Debug

- ✅ Breakpoints in Go files
- ✅ Variable inspection (primitives, structs, slices, maps)
- ✅ Call stack navigation
- ✅ Conditional breakpoints
- ✅ Expression evaluation in Debug Console
- ✅ Watch expressions
- ✅ Goroutine inspection
- ✅ Panic stack traces
- ✅ Interface value inspection

### Go-Specific Debugging Features

**Goroutine Debugging:**
- View all goroutines in Debug panel
- Switch between goroutines
- See goroutine states (running, blocked, etc.)
- Inspect goroutine-local variables

**Performance:**
- Fast attach/detach
- Minimal runtime overhead with `--continue` flag
- Can debug production binaries (if built with debug symbols)

**Tips for Debugging Go:**
- Use `runtime.Breakpoint()` for programmatic breakpoints
- Inspect `reflect.TypeOf()` to view interface types
- Use Debug Console to call functions in current context
- Set breakpoints in goroutines to debug concurrency
- Use `dlv trace` for tracing function calls (outside VS Code)

## Application Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Health check (returns status and timestamp) |
| `/debug-test?count=N` | GET | Test endpoint for debugging (creates N items with delays) |
| `/weatherforecast` | GET | Weather forecast (5-day sample data) |

## Gin Framework Notes

**Gin** is a high-performance HTTP web framework for Go:
- Fast HTTP router with zero allocations
- Middleware support
- JSON validation and binding
- Error management
- Query parameter binding

Example route handler:
```go
r.GET("/debug-test", func(c *gin.Context) {
    countStr := c.DefaultQuery("count", "3")
    count, err := strconv.Atoi(countStr)
    if err != nil || count < 1 || count > 20 {
        count = 3
    }

    items := make([]string, 0, count)
    for i := 0; i < count; i++ {
        items = append(items, "Item "+strconv.Itoa(i+1))
        time.Sleep(10 * time.Millisecond)
    }

    c.JSON(http.StatusOK, DebugTestResponse{
        Count:     count,
        Items:     items,
        Timestamp: time.Now().UTC().Format(time.RFC3339),
    })
})
```

## VS Code Extensions

Recommended extensions (auto-suggested when opening this folder):

- **Go** (golang.go) - Go language support and debugging
- **Kubernetes** (ms-kubernetes-tools.vscode-kubernetes-tools) - K8s management

## Management Commands

```bash
# Build debug image
./manage.sh build

# Push to registry
./manage.sh push

# Deploy to namespace
./manage.sh -n NAMESPACE deploy

# Port-forward debug port (2345) and attach debugger
./manage.sh -n NAMESPACE debug

# Port-forward application port
./manage.sh -n NAMESPACE port-forward [PORT]

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
   ps aux | grep "port-forward.*2345"
   ```

2. **Check pod is running:**
   ```bash
   ./manage.sh status
   # Pod should show "Running"
   ```

3. **Verify Delve is listening on 2345:**
   ```bash
   ./manage.sh logs
   # Should show "API server listening at: [::]:2345"
   ```

4. **Restart port-forward:**
   ```bash
   # Kill existing port-forward
   pkill -f "port-forward.*2345"

   # Start new port-forward
   ./manage.sh debug
   ```

### Breakpoints Not Hitting

**Symptom:** Breakpoints show as grey/hollow circles

**Solutions:**

1. **Ensure binary compiled with debug symbols:**
   - Check Dockerfile uses `-gcflags="all=-N -l"`
   - Rebuild: `./manage.sh build && ./manage.sh push && ./manage.sh restart`

2. **Verify source path mapping is correct:**
   - Check `.vscode/launch.json` has `substitutePath` configuration
   - Should map `${workspaceFolder}` to `/build` (the Docker build directory)
   - Example:
     ```json
     "substitutePath": [
         {
             "from": "${workspaceFolder}",
             "to": "/build"
         }
     ]
     ```
   - **Note:** Use `substitutePath` (not `remotePath`) for Go debugging
   - The path must match where source files were during compilation

3. **Install Delve locally if missing:**
   ```bash
   go install github.com/go-delve/delve/cmd/dlv@latest
   ```

4. **Check Delve is attached:**
   - VS Code should show "Go: Attached" or similar
   - Debug Console should show Delve connection message

5. **Restart debugging session:**
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
# - Missing dependencies (run go mod tidy)
# - Build errors (check Dockerfile)
# - Port conflicts
# - Application panics on startup
```

### Port-Forward Connection Drops

**Symptom:** Debugger disconnects randomly

**Solutions:**

- **Network timeouts**: kubectl port-forward can timeout on idle connections
- **Workaround**: Restart port-forward when needed
- **Alternative**: Use `kubectl port-forward svc/go-gin 2345:2345` for service-level forwarding

### Common Issues

**Issue:** "Address already in use: 2345"
**Solution:** Another process is using port 2345 locally. Kill it: `lsof -ti:2345 | xargs kill`

**Issue:** Debugger connects but shows wrong line numbers
**Solution:** Source code out of sync. Rebuild and redeploy: `./manage.sh build && ./manage.sh push && ./manage.sh restart`

**Issue:** Can't inspect variable values
**Solution:** Variable may be optimized out. Ensure `-gcflags="all=-N -l"` is used in build

## Configuration Details

### Build Flags

| Flag | Description |
|------|-------------|
| `-gcflags="all=-N"` | Disable optimizations |
| `-gcflags="all=-l"` | Disable function inlining |

These flags preserve debug information and prevent the compiler from optimizing away variables.

### Kubernetes Labels

The deployment uses these labels:
```yaml
app: go-gin
framework: gin
language: go
version: "1.23"
debug-enabled: "true"
```

## VS Code Debug Configuration

The `.vscode/launch.json` uses Go remote attach configuration:

```json
{
  "name": "Attach to Remote Pod",
  "type": "go",
  "request": "attach",
  "mode": "remote",
  "remotePath": "/app",
  "port": 2345,
  "host": "localhost"
}
```

This method:
- Connects to Delve on localhost:2345
- Requires port-forward to be running
- Maps local source files to remote path `/app`
- Uses Delve's Debug Adapter Protocol (DAP)

## Difference from Other Language Debugging

Go debugging with Delve has some unique characteristics compared to other languages:

### vs .NET (C#/F#)
- **.NET:** Uses vsdbg with kubectl exec and pipe transport
- **Go:** Uses Delve with port-forwarding (similar to Node.js)
- **Go:** Requires build flags `-gcflags="all=-N -l"` to preserve debug symbols
- **Go:** Application starts immediately with `--continue` flag

### vs Node.js
- **Node.js:** Enabled via `--inspect` command-line flag, no build changes
- **Go:** Requires special build flags and running under Delve
- **Both:** Use port-forwarding for debugging (Node.js: 9229, Go: 2345)
- **Both:** TCP-based debug protocol

### vs Python
- **Python:** Requires code changes (`import debugpy`, `debugpy.listen()`)
- **Go:** No code changes, but requires build configuration and Delve wrapper
- **Both:** Use port-forwarding
- **Go:** More performant, no runtime overhead when not debugging

### Summary Table

| Language | Code Changes | Build Changes | Debug Method | Port |
|----------|--------------|---------------|--------------|------|
| .NET | ❌ None | ❌ None | kubectl exec | N/A |
| Node.js | ❌ None | ❌ None | Port-forward | 9229 |
| Python | ✅ Required | ❌ None | Port-forward | 5678 |
| Go | ❌ None | ✅ Required | Port-forward | 2345 |

**Go's approach** requires special build flags but no code changes, and the debugger wraps the application transparently.

## Integration with nginx-dev-gateway

This example works with [nginx-dev-gateway](https://github.com/nathanfox/nginx-dev-gateway):

```bash
# Deploy nginx gateway to your namespace
# (See nginx-dev-gateway documentation)

# Access via gateway
curl http://localhost:8080/go-api/health
```

## Performance Notes

**Debug Mode (Delve with --continue):**
- Minimal performance impact when not attached
- Slight overhead when debugger attached
- Binary is larger due to debug symbols
- Should not be used in production

**Resource Usage:**
- CPU request: 100m, limit: 500m
- Memory request: 128Mi, limit: 512Mi

## Go Debugging Best Practices

1. **Always use `-gcflags="all=-N -l"`** for debug builds
2. **Use `--continue` flag** so application starts immediately
3. **Inspect goroutines** to understand concurrent behavior
4. **Use conditional breakpoints** to filter high-frequency events
5. **Debug Console** can evaluate Go expressions
6. **Profile with pprof** for performance issues (outside debugger)

## Next Steps

- Try debugging goroutines and concurrency
- Set conditional breakpoints on query parameters
- Use Debug Console to call functions at runtime
- Deploy multiple examples and debug service-to-service calls
- Integrate with nginx-dev-gateway for microservices debugging

## References

- [Delve Debugger Documentation](https://github.com/go-delve/delve)
- [VS Code Go Debugging](https://github.com/golang/vscode-go/wiki/debugging)
- [Gin Web Framework](https://gin-gonic.com/)
- [Go Debugging with Delve](https://github.com/go-delve/delve/tree/master/Documentation)

## Contributing

Found an issue? See [CONTRIBUTING.md](../../CONTRIBUTING.md) for how to report bugs or suggest improvements.