# Node.js Express Remote Debugging Example

Remote debugging example for Node.js Express applications running in Kubernetes pods.

## Overview

This example demonstrates how to:
- Build a Docker image with Node.js Inspector Protocol enabled
- Deploy to Kubernetes with debug port exposed
- Port-forward debug port (9229) from local machine to remote pod
- Attach VS Code debugger using Node.js Inspector Protocol
- Set breakpoints, inspect variables, and step through async code

**Language:** Node.js (v22)
**Framework:** Express
**Debugger:** Node.js Inspector Protocol
**Debug Method:** Port-forward to debug port 9229

## Prerequisites

- Kubernetes cluster (local or remote)
- kubectl configured and connected
- Docker for building images
- VS Code with extensions:
  - ESLint (dbaeumer.vscode-eslint) - optional
  - Kubernetes (ms-kubernetes-tools.vscode-kubernetes-tools)
- Node.js 18+ (for local development)

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
nodejs-express/
├── src/
│   └── index.js                 # Express application
├── k8s/                         # Kubernetes manifests
│   ├── deployment.yaml          # Deployment with debug config
│   └── service.yaml             # Service definition
├── .vscode/                     # VS Code configuration
│   ├── launch.json             # Debug configuration (attach via port 9229)
│   ├── tasks.json              # Build/deploy tasks
│   └── extensions.json         # Recommended extensions
├── Dockerfile                   # Node.js image with --inspect flag
├── .dockerignore               # Docker ignore patterns
├── package.json                 # Node.js dependencies
├── manage.sh                    # Example management script
└── README.md                    # This file
```

## Building the Docker Image

```bash
# Build debug image (with --inspect flag)
./manage.sh build

# Build with custom tag
./manage.sh -t v1.0.0 build
```

### Docker Configuration

The Dockerfile runs Node.js with the `--inspect` flag:

```dockerfile
CMD ["node", "--inspect=0.0.0.0:9229", "src/index.js"]
```

This:
- Enables Node.js Inspector Protocol
- Listens on all interfaces (0.0.0.0)
- Uses port 9229 (Node.js default debug port)
- Allows remote debuggers to connect

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

The Node.js Inspector Protocol requires port-forwarding port 9229:

```bash
# Port-forward debug port (runs in foreground)
./manage.sh debug

# Or run in background
./manage.sh port-forward-debug &
```

**What this does:**
- Forwards local port 9229 → pod port 9229
- VS Code debugger connects to localhost:9229
- Node.js Inspector Protocol handles debugging

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
- VS Code connects to localhost:9229
- Node.js Inspector Protocol accepts connection
- Debugger attaches to running Node.js process
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

1. **Set a breakpoint** in `src/index.js` at line 15 (inside the `/debug-test` handler)
2. **Start port-forward**: `./manage.sh debug` (in separate terminal)
3. **Attach debugger** (F5 in VS Code)
4. **Make a request**: `curl http://localhost:8080/debug-test?count=3`
5. **Breakpoint hits** - execution pauses at line 15
6. **Inspect variables**:
   - Hover over `count` - shows the value (3)
   - Check Variables panel - see `items`, `i`, `req`, `res`
   - Inspect async context and promises
7. **Step through code**:
   - F10 (step over) - executes current line
   - F11 (step into) - step into async functions
   - Watch the `items` array grow as you step through the loop
8. **Continue execution** - F5 to resume

### What You Can Debug

- ✅ Breakpoints in JavaScript files
- ✅ Variable inspection (primitives, objects, arrays, closures)
- ✅ Call stack navigation (including async call stacks)
- ✅ Conditional breakpoints
- ✅ Expression evaluation in Debug Console
- ✅ Watch expressions
- ✅ Exception breakpoints
- ✅ Async/await debugging
- ✅ Promise inspection

### Node.js-Specific Debugging Features

**Async/Await Debugging:**
- Full async call stack visible
- Can pause in async functions
- Promise states inspectable
- Unhandled promise rejection detection

**Performance:**
- Hot code reload with nodemon (dev mode)
- Source maps supported (if using TypeScript/Babel)
- Memory profiling available via Inspector Protocol

**Tips for Debugging Node.js:**
- Use `debugger;` statement for programmatic breakpoints
- Enable "Pause on caught exceptions" for error tracking
- Use Debug Console to evaluate expressions in current context
- Inspect `process.env` to view environment variables

## Application Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Health check (returns status and timestamp) |
| `/debug-test?count=N` | GET | Async endpoint for debugging (creates N items with delays) |
| `/weatherforecast` | GET | Weather forecast (5-day sample data) |

## Express Framework Notes

**Express** is a minimal and flexible Node.js web application framework:
- Middleware-based request handling
- Simple routing (`app.get()`, `app.post()`, etc.)
- JSON response with `res.json()`
- Query parameter access via `req.query`

Example async route handler:
```javascript
app.get('/debug-test', async (req, res) => {
  const count = parseInt(req.query.count) || 3;
  const items = [];

  for (let i = 0; i < count; i++) {
    items.push(`Item ${i + 1}`);
    await new Promise(resolve => setTimeout(resolve, 10));
  }

  res.json({ count, items, timestamp: new Date().toISOString() });
});
```

## VS Code Extensions

Recommended extensions (auto-suggested when opening this folder):

- **ESLint** (dbaeumer.vscode-eslint) - JavaScript linting (optional)
- **Kubernetes** (ms-kubernetes-tools.vscode-kubernetes-tools) - K8s management

## Management Commands

```bash
# Build debug image
./manage.sh build

# Push to registry
./manage.sh push

# Deploy to namespace
./manage.sh -n NAMESPACE deploy

# Port-forward debug port (9229) and attach debugger
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
   ps aux | grep "port-forward.*9229"
   ```

2. **Check pod is running:**
   ```bash
   ./manage.sh status
   # Pod should show "Running"
   ```

3. **Verify Node.js is listening on 9229:**
   ```bash
   ./manage.sh shell
   netstat -tlnp | grep 9229
   # Should show node listening on 0.0.0.0:9229
   ```

4. **Restart port-forward:**
   ```bash
   # Kill existing port-forward
   pkill -f "port-forward.*9229"
   
   # Start new port-forward
   ./manage.sh debug
   ```

### Breakpoints Not Hitting

**Symptom:** Breakpoints show as grey/hollow circles

**Solutions:**

1. **Ensure source paths match:**
   - Check `.vscode/launch.json` localRoot and remoteRoot
   - localRoot: `${workspaceFolder}/src`
   - remoteRoot: `/app/src`

2. **Verify files are mounted correctly:**
   ```bash
   ./manage.sh shell
   ls -la /app/src
   # Should show index.js
   ```

3. **Check Node.js version compatibility:**
   - VS Code Node debugger works best with Node.js 14+
   - This example uses Node.js 22

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
# - Missing dependencies (run npm install)
# - Syntax errors in JavaScript
# - Port conflicts
# - Missing environment variables
```

### Port-Forward Connection Drops

**Symptom:** Debugger disconnects randomly

**Solutions:**

- **Network timeouts**: kubectl port-forward can timeout on idle connections
- **Workaround**: Set longer timeouts or restart port-forward when needed
- **Alternative**: Use `kubectl port-forward svc/nodejs-express 9229:9229` for service-level forwarding

### Common Issues

**Issue:** "EADDRINUSE: address already in use :::9229"
**Solution:** Another process is using port 9229 locally. Kill it: `lsof -ti:9229 | xargs kill`

**Issue:** Debugger connects but breakpoints don't pause execution
**Solution:** Ensure you're not in production mode. Check `NODE_ENV=development`

**Issue:** Can't see async call stacks
**Solution:** Enable "Async Stack Traces" in VS Code debug settings

## Configuration Details

### Dockerfile Build Args

- `BUILD_MODE` - Set to `debug` or `production` (default: `production`)
  - Debug mode same as production for Node.js (Inspector always available)
  - Use `NODE_ENV` to control application behavior

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `NODE_ENV` | Node.js environment | `development` |
| `PORT` | HTTP server port | `8080` |

### Kubernetes Labels

The deployment uses these labels:
```yaml
app: nodejs-express
framework: express
language: nodejs
version: "22"
debug-enabled: "true"
```

## VS Code Debug Configuration

The `.vscode/launch.json` uses standard Node.js attach configuration:

```json
{
  "name": "Attach to Remote Pod",
  "type": "node",
  "request": "attach",
  "address": "localhost",
  "port": 9229,
  "localRoot": "${workspaceFolder}/src",
  "remoteRoot": "/app/src"
}
```

This method:
- Connects to Node.js Inspector Protocol on localhost:9229
- Requires port-forward to be running
- Maps local source files to remote paths
- Supports source maps for transpiled code

## Difference from .NET Debugging

Unlike .NET examples (C#/F#) which use `kubectl exec` with pipeTransport:
- **Node.js uses port-forwarding** to debug port 9229
- **Inspector Protocol** is TCP-based (vs vsdbg stdin/stdout)
- **More like traditional remote debugging** (network connection)
- **Requires separate port-forward process**

Both approaches work well, just different protocols and connection methods.

## Integration with nginx-dev-gateway

This example works with [nginx-dev-gateway](https://github.com/nathanfox/nginx-dev-gateway):

```bash
# Deploy nginx gateway to your namespace
# (See nginx-dev-gateway documentation)

# Access via gateway
curl http://localhost:8080/nodejs-api/health
```

## Performance Notes

**Debug Mode (--inspect):**
- Minimal performance impact when not attached
- Slight overhead when debugger attached
- Can be used in production (but not recommended)

**Resource Usage:**
- CPU request: 100m, limit: 500m
- Memory request: 128Mi, limit: 512Mi

## Node.js Debugging Best Practices

1. **Use `debugger;` statements** - programmatic breakpoints that work everywhere
2. **Enable async stack traces** - helps track promise chains
3. **Use Debug Console** - evaluate expressions in paused context
4. **Profile memory** - Inspector Protocol supports heap snapshots
5. **Test error paths** - use "Pause on exceptions" to catch errors
6. **Hot reload** - use nodemon for faster development (not in production)

## Next Steps

- Try debugging async/await code with step-through
- Set conditional breakpoints on request parameters
- Use Debug Console to modify variables at runtime
- Deploy multiple examples and debug service-to-service calls
- Integrate with nginx-dev-gateway for microservices debugging

## References

- [Node.js Inspector Protocol](https://nodejs.org/en/docs/guides/debugging-getting-started/)
- [VS Code Node.js Debugging](https://code.visualstudio.com/docs/nodejs/nodejs-debugging)
- [Express Documentation](https://expressjs.com/)

## Contributing

Found an issue? See [CONTRIBUTING.md](../../CONTRIBUTING.md) for how to report bugs or suggest improvements.
