# F# Giraffe .NET 8 Remote Debugging Example

Remote debugging example for F# Giraffe applications running in Kubernetes pods.

## Overview

This example demonstrates how to:
- Build a debug-enabled Docker image for F# with Giraffe framework
- Deploy to Kubernetes with debug configuration
- Attach VS Code debugger from local machine to remote pod via kubectl exec
- Set breakpoints, inspect variables, and step through functional code

**Language:** F#
**Framework:** Giraffe on ASP.NET Core 8.0
**Debugger:** vsdbg (Visual Studio Debugger)
**Debug Method:** kubectl exec with pipeTransport

## Prerequisites

- Kubernetes cluster (local or remote)
- kubectl configured and connected
- Docker for building images
- VS Code with extensions:
  - Ionide-fsharp (Ionide.ionide-fsharp)
  - C# (ms-dotnettools.csharp)
  - Kubernetes (ms-kubernetes-tools.vscode-kubernetes-tools)
- .NET 8 SDK (for local development)

## Quick Start

```bash
# Set your developer namespace
export NAMESPACE=dev-yourname

# Build the Docker image
./manage.sh build

# Deploy to Kubernetes
./manage.sh deploy

# Verify pod is ready
./manage.sh debug

# Open in VS Code and press F5 to attach debugger
code .
```

## Project Structure

```
fsharp-giraffe-dotnet8/
├── src/
│   └── FSharpGiraffe/           # F# Giraffe project
│       ├── Program.fs           # Main application code
│       └── FSharpGiraffe.fsproj # Project file
├── k8s/                         # Kubernetes manifests
│   ├── deployment.yaml          # Deployment with debug config
│   └── service.yaml             # Service definition
├── .vscode/                     # VS Code configuration
│   ├── launch.json             # Debug configuration (kubectl exec)
│   ├── tasks.json              # Build/deploy tasks
│   └── extensions.json         # Recommended extensions
├── Dockerfile                   # Multi-stage build with vsdbg
├── .dockerignore               # Docker ignore patterns
├── manage.sh                    # Example management script
└── README.md                    # This file
```

## Building the Docker Image

The Dockerfile supports both debug and production builds:

```bash
# Build debug image (includes vsdbg)
./manage.sh build

# Build with custom tag
./manage.sh -t v1.0.0 build
```

### Debug vs Production

**Debug mode (default for manage.sh):**
- Includes vsdbg debugger installed from aka.ms/getvsdbgsh
- Debug symbols included (Debug configuration)
- ASPNETCORE_ENVIRONMENT=Development
- Port 8080 exposed

**Production mode:**
- Release configuration (optimized)
- No debug tools
- Smaller image size

To build production:
```bash
docker build --build-arg BUILD_MODE=production -t fsharp-giraffe:prod .
```

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

### Step 1: Ensure Pod is Ready

```bash
./manage.sh debug
```

Output:
```
[INFO] Checking pod status for debugging...
[SUCCESS] Pod is ready for debugging: fsharp-giraffe-xxx-yyy
```

### Step 2: Set NAMESPACE Environment Variable

The VS Code launch configuration uses `${env:NAMESPACE}` as default:

```bash
export NAMESPACE=dev-yourname
```

### Step 3: Open in VS Code and Attach

```bash
# Open this example in VS Code
code .
```

1. Ensure recommended extensions are installed (VS Code will prompt)
2. Open the "Run and Debug" panel (Ctrl+Shift+D / Cmd+Shift+D)
3. Select **"Attach to Remote Pod"** from the dropdown
4. Press **F5** or click the green play button
5. Enter namespace (defaults to $NAMESPACE)
6. Enter pod name when prompted

**What happens:**
- VS Code uses kubectl exec to connect to the pod
- vsdbg (installed in the container) is invoked
- Debugger attaches to the running .NET process
- No port-forwarding needed for debugging!

## Debugging Walkthrough

### Test the Application

```bash
# In a separate terminal, port-forward the application
kubectl port-forward -n $NAMESPACE pod/$(kubectl get pod -n $NAMESPACE -l app=fsharp-giraffe -o jsonpath='{.items[0].metadata.name}') 8080:8080

# Make requests
curl http://localhost:8080/health
curl http://localhost:8080/debug-test?count=5
curl http://localhost:8080/weatherforecast
```

### Debug Session Example

1. **Set a breakpoint** in `Program.fs` at line 23 (inside the `debugTestHandler` function)
2. **Attach debugger** (F5 in VS Code)
3. **Make a request**: `curl http://localhost:8080/debug-test?count=3`
4. **Breakpoint hits** - execution pauses at line 23
5. **Inspect variables**:
   - Hover over `count` - shows the value (3)
   - Check Variables panel - see functional values, closures
   - Inspect `items` list as it's computed
6. **Step through code**:
   - F10 (step over) - executes current line
   - Watch functional transformations happen
7. **Continue execution** - F5 to resume

### What You Can Debug

- ✅ Breakpoints in F# code
- ✅ Variable inspection (including function closures)
- ✅ Call stack navigation (including functional composition)
- ✅ Conditional breakpoints
- ✅ Expression evaluation in Debug Console
- ✅ Watch expressions
- ✅ Exception breakpoints
- ✅ Pipeline debugging (F# pipe operators)

### F#-Specific Debugging Notes

**Functional Programming Considerations:**
- F# closures and lambda functions can be inspected
- Pattern matching can be stepped through
- List comprehensions show intermediate values
- Discriminated unions display with proper types
- Record types show all fields

**Tips for Debugging F# Code:**
- Set breakpoints on `let` bindings to inspect computed values
- Use conditional breakpoints with F# expressions
- Pipeline operations (`|>`) can be stepped through
- Pattern matching branches can each have breakpoints

## Application Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Health check (returns status and timestamp) |
| `/debug-test?count=N` | GET | Simple endpoint for debugging (creates N items using F# list comprehension) |
| `/weatherforecast` | GET | Weather forecast (5-day sample data, functional style) |

## Giraffe Framework Notes

**Giraffe** is a functional ASP.NET Core micro web framework:
- Uses HttpHandler composition
- Functional routing with `choose` and `route`
- Type-safe JSON serialization
- Composable with F# operators (`>=>`)

Example handler:
```fsharp
let debugTestHandler: HttpHandler =
    fun next ctx ->
        let count = // extract query param
        let items = [ for i in 1 .. count -> sprintf "Item %d" i ]
        let response = {| Count = count; Items = items; Timestamp = DateTime.UtcNow |}
        json response next ctx
```

## VS Code Extensions

Required extensions (auto-suggested when opening this folder):

- **Ionide-fsharp** (Ionide.ionide-fsharp) - F# language support and IntelliSense
- **C#** (ms-dotnettools.csharp) - Required for vsdbg debugger
- **Kubernetes** (ms-kubernetes-tools.vscode-kubernetes-tools) - K8s management

## Management Commands

```bash
# Build debug image
./manage.sh build

# Deploy to namespace
./manage.sh -n NAMESPACE deploy

# Check if ready for debugging
./manage.sh -n NAMESPACE debug

# Port-forward application
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

**Symptom:** VS Code shows "Cannot connect to runtime process"

**Solutions:**

1. **Verify NAMESPACE env var or prompt:**
   ```bash
   echo $NAMESPACE
   # Or just enter it when prompted
   ```

2. **Check pod is running:**
   ```bash
   ./manage.sh status
   # Pod should show "Running"
   ```

3. **Verify vsdbg is in the container:**
   ```bash
   ./manage.sh shell
   ls -la /vsdbg/vsdbg
   # Should show the vsdbg executable
   ```

4. **Check kubectl connectivity:**
   ```bash
   kubectl exec -n $NAMESPACE -l app=fsharp-giraffe -- echo "Connected"
   # Should print "Connected"
   ```

### Breakpoints Not Hitting

**Symptom:** Breakpoints show as grey/hollow circles

**Solutions:**

1. **Ensure debug build is deployed:**
   ```bash
   # Rebuild and redeploy
   ./manage.sh build
   ./manage.sh deploy
   ```

2. **Verify source paths match:**
   - Check `.vscode/launch.json` sourceFileMap
   - Should map `/src/FSharpGiraffe` to local `${workspaceFolder}/src/FSharpGiraffe`

3. **Restart VS Code and reattach:**
   - Close VS Code
   - Reopen: `code .`
   - Attach debugger again (F5)

### Pod Crashes on Startup

**Symptom:** Pod status shows `CrashLoopBackOff`

**Solutions:**

```bash
# Check logs
./manage.sh logs

# Common issues:
# - Missing Giraffe package
# - F# compilation errors
# - Port conflicts
# - Application startup errors
```

### Common Issues

**Issue:** "No process with the given PID"
**Solution:** The pod may have restarted. Detach and reattach debugger (F5 again)

**Issue:** Slow debugging performance
**Solution:** Expected - debug builds disable optimizations. Use production builds for performance testing

**Issue:** F# IntelliSense not working
**Solution:** Ensure Ionide-fsharp extension is installed and project is restored (`dotnet restore`)

## Configuration Details

### Dockerfile Build Args

- `BUILD_MODE` - Set to `debug` (includes vsdbg) or `production` (default: `production`)

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `ASPNETCORE_ENVIRONMENT` | ASP.NET Core environment | `Development` |
| `ASPNETCORE_URLS` | Listening URLs | `http://+:8080` |

### Kubernetes Labels

The deployment uses these labels:
```yaml
app: fsharp-giraffe
framework: dotnet
language: fsharp
version: "8.0"
debug-enabled: "true"
```

## VS Code Debug Configuration

The `.vscode/launch.json` uses `pipeTransport` to connect via kubectl exec:

```json
{
  "name": "Attach to Remote Pod",
  "type": "coreclr",
  "request": "attach",
  "processId": "1",
  "pipeTransport": {
    "pipeProgram": "kubectl",
    "pipeArgs": ["exec", "-i", "-n", "${input:namespace}", "${input:podName}", "--"],
    "debuggerPath": "/vsdbg/vsdbg"
  }
}
```

This method:
- Uses stdin/stdout piping through kubectl
- No port-forwarding required for debugging
- Direct connection to vsdbg in the pod
- More reliable than TCP port-forwarding
- User prompted for namespace and pod name

## Integration with nginx-dev-gateway

This example works with [nginx-dev-gateway](https://github.com/nathanfox/nginx-dev-gateway):

```bash
# Deploy nginx gateway to your namespace
# (See nginx-dev-gateway documentation)

# Access via gateway
curl http://localhost:8080/fsharp-api/health
```

## Performance Notes

**Debug Mode:**
- Slower execution (optimizations disabled)
- Increased memory usage
- Not suitable for performance testing

**Resource Usage:**
- CPU request: 100m, limit: 500m
- Memory request: 128Mi, limit: 512Mi

## F# Debugging Best Practices

1. **Use meaningful `let` bindings** - makes debugging easier to follow
2. **Break up pipelines** - easier to set breakpoints on intermediate steps
3. **Avoid overly complex pattern matching in single expression** - split for debuggability
4. **Use type annotations** - helps debugger show proper types
5. **Test pure functions separately** - easier to reason about in debugger

## Next Steps

- Try setting breakpoints in functional pipelines
- Debug pattern matching with different cases
- Explore debugging list comprehensions
- Deploy multiple examples and debug service-to-service calls
- Integrate with nginx-dev-gateway

## References

- [vsdbg Documentation](https://github.com/dotnet/vscode-csharp/blob/main/debugger.md)
- [F# Debugging in VS Code](https://ionide.io/Editors/Code/getting_started.html)
- [Giraffe Documentation](https://github.com/giraffe-fsharp/Giraffe)
- [F# Guide](https://fsharp.org/)

## Contributing

Found an issue? See [CONTRIBUTING.md](../../CONTRIBUTING.md) for how to report bugs or suggest improvements.