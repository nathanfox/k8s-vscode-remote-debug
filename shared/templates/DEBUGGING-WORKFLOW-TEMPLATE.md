# [Language/Framework] Debugging Workflow

Step-by-step guide for remote debugging [Language/Framework] applications in Kubernetes.

## Prerequisites Checklist

- [ ] Kubernetes cluster accessible via kubectl
- [ ] Docker installed for building images
- [ ] VS Code with required extensions installed
- [ ] Developer namespace created (`dev-yourname`)
- [ ] [Language-specific tools installed]

## Workflow Overview

```
1. Build debug image
   ↓
2. Deploy to Kubernetes
   ↓
3. Verify pod is running
   ↓
4. Setup port-forward / debug connection
   ↓
5. Attach VS Code debugger
   ↓
6. Set breakpoints & debug
```

## Step-by-Step Instructions

### Step 1: Build Debug-Enabled Image

Build the Docker image with debug configuration:

```bash
# From the example directory
cd examples/[example-name]

# Build debug image
./manage.sh build
```

**What happens:**
- Dockerfile builds with `BUILD_MODE=debug`
- [Debugger name] is installed in the image
- Debug symbols are included
- Image is tagged as `[image-name]:latest`

**Verify build:**
```bash
docker images | grep [image-name]
```

### Step 2: Deploy to Your Namespace

Deploy the application to your developer namespace:

```bash
# Set namespace
export NAMESPACE=dev-yourname

# Deploy
./manage.sh deploy
```

**What happens:**
- Namespace is created if it doesn't exist
- Kubernetes manifests are applied (deployment, service)
- Pod starts with debug configuration
- Debug port [port] is exposed

**Verify deployment:**
```bash
# Check pods
./manage.sh status

# Should show:
# NAME                    READY   STATUS    RESTARTS   AGE
# [app-name]-xxx-yyy      1/1     Running   0          30s
```

### Step 3: Wait for Pod to Be Ready

Ensure the pod is fully running:

```bash
# Watch pod status
kubectl get pods -n $NAMESPACE -w

# Or check logs
./manage.sh logs
```

**Expected log output:**
```
[Expected startup messages showing debugger is listening]
```

### Step 4: Setup Debug Connection

#### Method A: kubectl port-forward (Most Common)

```bash
# In a separate terminal, run:
./manage.sh debug

# Output:
# [INFO] Setting up port-forward: localhost:[local-port] -> [pod-name]:[remote-port]
# Forwarding from 127.0.0.1:[local-port] -> [remote-port]
# Forwarding from [::1]:[local-port] -> [remote-port]
```

**Port mapping:**
- Local port `[local-port]` → Pod debug port `[remote-port]`

**Keep this terminal running** during your debug session.

#### Method B: kubectl exec with pipeTransport (for .NET)

For .NET examples using vsdbg, the connection is established via `kubectl exec` in the VS Code launch configuration. No manual port-forward needed.

### Step 5: Open in VS Code

```bash
# Open the example directory in VS Code
code .

# Or if already open, ensure you're in the example directory
```

**Verify VS Code setup:**
1. Check `.vscode/launch.json` exists
2. Check recommended extensions are installed (bottom-right prompt)
3. Open the "Run and Debug" panel (Ctrl+Shift+D / Cmd+Shift+D)

### Step 6: Set Breakpoints

1. Open `[main-source-file]` in VS Code
2. Click in the gutter (left of line numbers) to set a breakpoint
3. A red dot appears indicating an active breakpoint

**Good places to set breakpoints:**
- `[File:Line]` - [Description of what happens here]
- `[File:Line]` - [Description]
- `[File:Line]` - [Description]

### Step 7: Attach Debugger

1. In VS Code, go to "Run and Debug" panel (Ctrl+Shift+D)
2. Select **"Attach to Remote Pod"** from the dropdown
3. Press **F5** or click the green play button

**Expected behavior:**
- Debug console opens
- Status bar turns orange (debug mode)
- Message: "[Debugger connected message]"

**If connection fails:**
- See [Troubleshooting](#troubleshooting) section below

### Step 8: Trigger the Code

Make a request to your application to trigger the breakpoint:

```bash
# In another terminal:
# Port-forward the application port (if not already done)
kubectl port-forward -n $NAMESPACE pod/[pod-name] 8080:8080

# Make a request
curl http://localhost:8080/[endpoint]

# Or use browser:
open http://localhost:8080/[endpoint]
```

### Step 9: Debug Session

When the breakpoint hits:

1. **Execution pauses** - yellow highlight shows current line
2. **Variables panel** shows:
   - Local variables
   - Function parameters
   - [Language-specific variable types]
3. **Call stack** shows the execution path
4. **Debug toolbar** appears with controls

**Debug controls:**
- **Continue (F5)** - Resume execution
- **Step Over (F10)** - Execute current line, don't enter functions
- **Step Into (F11)** - Enter function calls
- **Step Out (Shift+F11)** - Exit current function
- **Restart** - Restart debug session
- **Stop** - Disconnect debugger

**Try these actions:**
- Hover over variables to see values
- Click variables in Variables panel to inspect
- Type expressions in Debug Console: `[example-expression]`
- Add watches in Watch panel for tracking values

### Step 10: Iterate

1. Make code changes locally
2. Rebuild and redeploy:
   ```bash
   ./manage.sh build
   ./manage.sh deploy
   ./manage.sh debug  # Restart port-forward
   ```
3. Reattach debugger (F5)
4. Test changes

## Debugging Scenarios

### Scenario 1: Debug API Request Handling

**Goal:** Step through request processing

1. Set breakpoint at request entry point: `[File:Line]`
2. Attach debugger
3. Send request: `curl -X POST http://localhost:8080/[endpoint]`
4. Step through the request handler
5. Inspect request data, parameters, headers

### Scenario 2: Debug Async/Concurrent Code

**Goal:** Understand async execution flow

1. Set breakpoints in async functions
2. Use call stack to track async context
3. [Language-specific async debugging tips]

### Scenario 3: Debug Error Conditions

**Goal:** Understand error handling

1. Set breakpoints in error handlers
2. Trigger error: `curl http://localhost:8080/[error-endpoint]`
3. Inspect error object and stack trace
4. Step through error recovery logic

### Scenario 4: Conditional Breakpoints

**Goal:** Break only on specific conditions

1. Right-click breakpoint → "Edit Breakpoint"
2. Add condition: `[example-condition]`
3. Breakpoint only triggers when condition is true

## Advanced Debugging

### Watch Expressions

Add expressions to monitor across execution:

1. In Watch panel, click "+"
2. Enter expression: `[example-expression]`
3. Value updates as you step through code

### Debug Console

Execute code in the current context:

```
> [example-debug-command]
[expected-output]
```

### Logpoints

Log without stopping execution:

1. Right-click in gutter → "Add Logpoint"
2. Enter message: `Value is {[variable-name]}`
3. Execution continues, messages appear in Debug Console

### Hot Reload (if supported)

[Language-specific hot reload instructions, if applicable]

## Cleaning Up

When done debugging:

```bash
# Stop port-forward (Ctrl+C in that terminal)

# Optionally delete deployment
./manage.sh delete

# Or delete entire namespace
./manage.sh -n $NAMESPACE delete-ns
```

## Troubleshooting

### Debugger Won't Connect

**Symptom:** VS Code shows "Cannot connect to runtime process"

**Solutions:**
1. Verify pod is running: `./manage.sh status`
2. Check port-forward is active: `ps aux | grep port-forward`
3. Restart port-forward:
   ```bash
   # Kill existing: Ctrl+C
   ./manage.sh debug
   ```
4. Check debugger is listening in pod:
   ```bash
   ./manage.sh shell
   # [Command to check debugger process]
   ```

### Breakpoints Show Grey/Hollow Circle

**Symptom:** Breakpoints aren't being hit

**Solutions:**
1. Ensure debug build is deployed (not production)
2. Verify source code matches deployed version
3. Check path mappings in `.vscode/launch.json`
4. [Language-specific source mapping checks]

### Source Code Out of Sync

**Symptom:** Debugger shows different code than your editor

**Solutions:**
1. Rebuild with latest code: `./manage.sh build`
2. Redeploy: `./manage.sh deploy`
3. Restart debug session

### Pod Crashes on Startup

**Symptom:** Pod status shows `CrashLoopBackOff`

**Solutions:**
1. Check logs: `./manage.sh logs`
2. Look for error messages
3. Verify debug configuration in Dockerfile
4. Check resource limits: `kubectl describe pod -n $NAMESPACE [pod-name]`

### Performance Issues

**Symptom:** Application runs slowly in debug mode

**Expected:** Debug mode is slower than production
- Optimizations disabled
- Debugger overhead
- Not suitable for performance testing

## Tips & Best Practices

### Efficient Debugging

- ✅ Use conditional breakpoints to reduce noise
- ✅ Set breakpoints before attaching (faster)
- ✅ Use logpoints for quick inspection without stopping
- ✅ Keep debug terminal open for full session

### Namespace Management

- ✅ Use descriptive namespace names: `dev-yourname`
- ✅ Clean up old namespaces regularly
- ✅ One namespace per developer
- ✅ Don't debug in shared namespaces

### Docker Image Management

- ✅ Tag images with versions for tracking
- ✅ Clean up old images: `docker image prune`
- ✅ Separate debug and production images
- ✅ Keep debug images out of production registries

## Next Steps

- [ ] Try debugging another language example
- [ ] Debug service-to-service calls with nginx-dev-gateway
- [ ] Set up debugging for your own application
- [ ] Explore VS Code debugging features

## Additional Resources

- [VS Code Debugging Documentation](https://code.visualstudio.com/docs/editor/debugging)
- [[Language] Debugging Guide](URL)
- [[Debugger] Documentation](URL)
- [Kubernetes Debugging Guide](https://kubernetes.io/docs/tasks/debug/)

## Questions?

See the main repository [troubleshooting guide](../../docs/troubleshooting.md) or open an issue.