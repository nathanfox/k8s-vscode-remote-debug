# [Language/Framework Name] Remote Debugging Example

> Replace [Language/Framework Name] with the actual name, e.g., "C# .NET 8 Web API"

Remote debugging example for [Language/Framework] applications running in Kubernetes pods.

## Overview

This example demonstrates how to:
- Build a debug-enabled Docker image for [Language/Framework]
- Deploy to Kubernetes with debug configuration
- Attach VS Code debugger from local machine to remote pod
- Set breakpoints, inspect variables, and step through code

**Language:** [Language]
**Framework:** [Framework Name + Version]
**Debugger:** [Debugger Name, e.g., vsdbg, Node Inspector, debugpy]
**Debug Method:** [kubectl port-forward / kubectl exec with pipeTransport]

## Prerequisites

- Kubernetes cluster (local or remote)
- kubectl configured and connected
- Docker for building images
- VS Code with extensions:
  - [List required VS Code extensions]
- [Any language-specific tools, e.g., .NET SDK, Node.js]

## Quick Start

```bash
# Set your developer namespace
export NAMESPACE=dev-yourname

# Build the Docker image
./manage.sh build

# Deploy to Kubernetes
./manage.sh deploy

# Set up debugging (port-forward)
./manage.sh debug

# Open VS Code and press F5 to attach debugger
```

## Project Structure

```
[example-name]/
├── src/                        # Application source code
├── k8s/                        # Kubernetes manifests
│   ├── namespace.yaml
│   ├── deployment.yaml
│   └── service.yaml
├── .vscode/                    # VS Code configuration
│   ├── launch.json            # Debug configuration
│   ├── tasks.json             # Build/deploy tasks
│   └── extensions.json        # Recommended extensions
├── Dockerfile                  # Multi-stage build with debug support
├── manage.sh                   # Example-specific management script
└── README.md                   # This file
```

## Building the Docker Image

The Dockerfile supports both debug and production builds:

```bash
# Build debug image (includes debugger)
./manage.sh build

# Build with custom tag
./manage.sh -t v1.0.0 build

# Build production image (optional)
docker build --build-arg BUILD_MODE=production -t [image-name]:prod .
```

### Debug vs Production

**Debug mode:**
- Includes debugger ([debugger name])
- Debug symbols included
- [Any other debug-specific configurations]

**Production mode:**
- Optimized binary
- No debug tools
- Smaller image size

## Deploying to Kubernetes

### Deploy to Your Namespace

```bash
# Create namespace (first time only)
./manage.sh -n dev-yourname create-ns

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

### Step 1: Start Port Forwarding

```bash
./manage.sh debug
```

This sets up port forwarding:
- **Local port [port]** → **Remote pod port [port]** (debugger)
- Keep this terminal open while debugging

### Step 2: Configure VS Code

The `.vscode/launch.json` is pre-configured for remote debugging.

Key configuration:
```json
{
  "type": "[debugger-type]",
  "request": "attach",
  "name": "Attach to Remote Pod",
  // [Add relevant configuration details]
}
```

### Step 3: Attach Debugger

1. Open this project folder in VS Code
2. Set breakpoints in your code
3. Press **F5** or click "Run and Debug"
4. Select "Attach to Remote Pod"

## Debugging Walkthrough

### Test the Application

```bash
# Get the pod name
POD_NAME=$(kubectl get pods -n $NAMESPACE -l app=[app-label] -o jsonpath='{.items[0].metadata.name}')

# Port forward the application (in another terminal)
kubectl port-forward -n $NAMESPACE pod/$POD_NAME 8080:8080

# Make a request
curl http://localhost:8080/[endpoint]
```

### Debug Session Example

1. **Set a breakpoint** in [specific file:line]
2. **Make a request** to trigger the endpoint
3. **Breakpoint hits** - execution pauses
4. **Inspect variables** in the Variables pane
5. **Step through code** using F10 (step over), F11 (step into)
6. **Evaluate expressions** in the Debug Console
7. **Continue execution** with F5

### What You Can Debug

- ✅ Breakpoints in all source files
- ✅ Variable inspection (locals, parameters, closures)
- ✅ Call stack navigation
- ✅ Conditional breakpoints
- ✅ Expression evaluation
- ✅ [Any language-specific features, e.g., async debugging, goroutines]

## Application Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/[endpoint]` | GET | [Description] |
| `/[endpoint]` | POST | [Description] |

## VS Code Extensions

Required extensions (auto-suggested when opening this folder):

- **[Extension Name]** - [Purpose]
- **[Extension Name]** - [Purpose]

## Management Commands

```bash
# Build image
./manage.sh build

# Deploy to namespace
./manage.sh -n NAMESPACE deploy

# Setup debugging (port-forward)
./manage.sh -n NAMESPACE debug

# View logs
./manage.sh -n NAMESPACE logs [--follow]

# Execute shell in pod
./manage.sh -n NAMESPACE shell

# Restart deployment
./manage.sh -n NAMESPACE restart

# Delete from namespace
./manage.sh -n NAMESPACE delete

# Show help
./manage.sh help
```

## Troubleshooting

### Pod Not Starting

```bash
# Check pod status
./manage.sh status

# View pod events
kubectl describe pod -n $NAMESPACE -l app=[app-label]

# Check logs
./manage.sh logs
```

### Debugger Not Connecting

1. **Verify port-forward is running:**
   ```bash
   # Should show port forwarding
   ps aux | grep "port-forward"
   ```

2. **Check debugger is listening in pod:**
   ```bash
   ./manage.sh shell
   # Inside pod: [command to verify debugger is running]
   ```

3. **Restart port-forward:**
   - Stop the `./manage.sh debug` terminal (Ctrl+C)
   - Run `./manage.sh debug` again

### Breakpoints Not Hitting

- ✅ Ensure you're running the debug build
- ✅ Verify source code matches deployed version
- ✅ Check file paths in launch.json
- ✅ [Language-specific debugging checks]

### Common Issues

**Issue:** [Common issue description]
**Solution:** [How to fix]

**Issue:** [Common issue description]
**Solution:** [How to fix]

## Configuration Details

### Dockerfile Build Args

- `BUILD_MODE` - Set to `debug` or `production` (default: `production`)

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `[VAR_NAME]` | [Description] | [Default] |

### Kubernetes Labels

The deployment uses these labels:
```yaml
app: [app-name]
framework: [framework]
language: [language]
debug-enabled: "true"
```

## Integration with nginx-dev-gateway

This example works with [nginx-dev-gateway](https://github.com/nathanfox/nginx-dev-gateway):

```bash
# Deploy nginx gateway to your namespace
# [Add specific integration steps]

# Access via gateway
curl http://localhost:8080/[route]
```

## Performance Notes

**Debug Mode:**
- [Performance characteristics]
- Not suitable for production use

**Resource Usage:**
- CPU: [typical usage]
- Memory: [typical usage]

## Next Steps

- Try the other language examples in `../`
- Deploy multiple examples and debug service-to-service calls
- Integrate with nginx-dev-gateway for microservices debugging

## References

- [Link to official debugger documentation]
- [Link to framework documentation]
- [Link to relevant debugging guides]

## Contributing

Found an issue? See [CONTRIBUTING.md](../../CONTRIBUTING.md) for how to report bugs or suggest improvements.