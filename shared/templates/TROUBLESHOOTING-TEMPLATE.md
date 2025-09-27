# [Language/Framework] Troubleshooting Guide

Common issues and solutions for remote debugging [Language/Framework] in Kubernetes.

## Quick Diagnostics

Run these commands to gather information before troubleshooting:

```bash
# Check pod status
./manage.sh -n $NAMESPACE status

# View recent logs
./manage.sh -n $NAMESPACE logs --tail 100

# Describe pod (events and config)
kubectl describe pod -n $NAMESPACE -l app=[app-name]

# Check if port-forward is running
ps aux | grep "port-forward"

# Test connectivity to pod
kubectl exec -n $NAMESPACE -l app=[app-name] -- [health-check-command]
```

## Connection Issues

### Debugger Cannot Connect

**Symptoms:**
- VS Code shows "Cannot connect to runtime process"
- Connection timeout errors
- Debug session immediately disconnects

**Diagnostic Steps:**

1. **Verify pod is running:**
   ```bash
   ./manage.sh status
   # Pod should show "Running" status
   ```

2. **Check port-forward is active:**
   ```bash
   ps aux | grep "port-forward.*[debug-port]"
   # Should show kubectl port-forward process
   ```

3. **Test debugger is listening in pod:**
   ```bash
   ./manage.sh shell
   # Inside pod:
   [command-to-check-debugger-process]
   # Example: ps aux | grep [debugger-name]
   ```

4. **Verify debug port configuration:**
   ```bash
   kubectl get pod -n $NAMESPACE [pod-name] -o yaml | grep -A 5 ports
   # Should show port [debug-port] exposed
   ```

**Solutions:**

**Solution 1: Restart port-forward**
```bash
# Kill existing port-forward (Ctrl+C or)
pkill -f "port-forward.*[debug-port]"

# Start fresh
./manage.sh debug
```

**Solution 2: Check firewall/network**
```bash
# Test localhost connection
telnet localhost [local-debug-port]
# Or
nc -zv localhost [local-debug-port]
```

**Solution 3: Verify VS Code configuration**
- Check `.vscode/launch.json` has correct port: `[debug-port]`
- Ensure configuration name matches what you're selecting
- [Language-specific configuration checks]

**Solution 4: Rebuild with debug enabled**
```bash
# Ensure debug build
./manage.sh build

# Verify BUILD_MODE=debug was used
docker inspect [image-name]:latest | grep BUILD_MODE
```

### Connection Succeeds But Immediately Disconnects

**Symptoms:**
- Debugger connects briefly then disconnects
- "Lost connection" messages

**Solutions:**

1. **Check pod isn't restarting:**
   ```bash
   kubectl get pods -n $NAMESPACE -w
   # Watch for restart count increasing
   ```

2. **Review pod logs for crashes:**
   ```bash
   ./manage.sh logs
   # Look for error messages or crash dumps
   ```

3. **Increase resource limits:**
   ```yaml
   # In k8s/deployment.yaml
   resources:
     limits:
       memory: 1Gi  # Increase if hitting OOM
       cpu: 1000m
   ```

## Breakpoint Issues

### Breakpoints Not Hitting

**Symptoms:**
- Breakpoints show as grey/hollow circles
- Code executes without stopping at breakpoints
- Breakpoints show "Unverified breakpoint" message

**Diagnostic Steps:**

1. **Check source code matches deployed version:**
   ```bash
   # Get file from running pod
   kubectl cp -n $NAMESPACE [pod-name]:/app/[source-file] /tmp/deployed-code

   # Compare with local
   diff [local-source-file] /tmp/deployed-code
   ```

2. **Verify debug symbols are present:**
   ```bash
   ./manage.sh shell
   # Inside pod, check for debug symbols/artifacts
   [command-to-verify-debug-symbols]
   ```

**Solutions:**

**Solution 1: Rebuild and redeploy**
```bash
# Rebuild with latest code
./manage.sh build

# Redeploy
./manage.sh deploy

# Wait for pod ready
kubectl wait --for=condition=ready pod -n $NAMESPACE -l app=[app-name]

# Reconnect debugger
./manage.sh debug  # Restart port-forward
# Then F5 in VS Code
```

**Solution 2: Check path mappings**

In `.vscode/launch.json`, verify paths:
```json
{
  "pathMappings": [
    {
      "localRoot": "${workspaceFolder}/src",
      "remoteRoot": "/app"
    }
  ]
}
```

**Solution 3: Verify file is included in build**
```bash
# Check file exists in image
docker run --rm [image-name]:latest ls -la /app/[source-file]
```

**Solution 4: [Language-specific solutions]**
[Add language-specific debugging configuration checks]

### Breakpoints Hit Wrong Line

**Symptoms:**
- Debugger stops at different line than set
- Line numbers seem offset

**Solutions:**

1. **Source map issues** (for compiled languages):
   - Ensure source maps are generated
   - Check source map paths in debug config
   - [Language-specific source map verification]

2. **Rebuild with debug optimization level:**
   ```dockerfile
   # In Dockerfile, ensure optimization is disabled
   [language-specific-debug-flags]
   ```

## Deployment Issues

### Pod Stuck in Pending

**Symptoms:**
- Pod shows "Pending" status for > 1 minute
- `kubectl get pods` shows 0/1 Ready

**Diagnostic Steps:**
```bash
kubectl describe pod -n $NAMESPACE -l app=[app-name]
# Look at Events section for:
# - "Insufficient cpu" or "Insufficient memory"
# - "ImagePullBackOff"
# - "FailedScheduling"
```

**Solutions:**

**Insufficient resources:**
```bash
# Check namespace quota
kubectl describe resourcequota -n $NAMESPACE

# Reduce resource requests if needed
# Edit k8s/deployment.yaml
```

**Image pull issues:**
```bash
# Check image exists locally
docker images | grep [image-name]

# If using registry, verify image was pushed
./manage.sh push

# Check image pull policy
kubectl get deployment -n $NAMESPACE [deployment-name] -o yaml | grep imagePullPolicy
```

### Pod in CrashLoopBackOff

**Symptoms:**
- Pod status shows `CrashLoopBackOff`
- Restart count keeps increasing

**Diagnostic Steps:**
```bash
# Get logs from crashed container
./manage.sh logs

# Get previous container logs
kubectl logs -n $NAMESPACE -l app=[app-name] --previous
```

**Common Causes & Solutions:**

**Cause: Application startup error**
```bash
# Check logs for error messages
./manage.sh logs | grep -i error

# Common issues:
# - Missing environment variables
# - Port already in use
# - [Language-specific startup errors]
```

**Cause: Debugger misconfiguration**
```bash
# Verify debugger is installed
./manage.sh shell
[command-to-check-debugger]

# Check debugger port is correct
kubectl get pod -n $NAMESPACE [pod-name] -o yaml | grep containerPort
```

**Cause: Health check failing**
```yaml
# In deployment.yaml, add or adjust probes:
livenessProbe:
  initialDelaySeconds: 30  # Increase delay
  periodSeconds: 10
readinessProbe:
  initialDelaySeconds: 10
  periodSeconds: 5
```

### Image Pull Errors

**Symptoms:**
- `ImagePullBackOff` or `ErrImagePull` status
- Event: "Failed to pull image"

**Solutions:**

```bash
# Ensure image is built
docker images | grep [image-name]

# If missing, build it
./manage.sh build

# Check deployment uses correct image name
kubectl get deployment -n $NAMESPACE [deployment-name] -o yaml | grep image:

# Verify imagePullPolicy allows local images
# Should be: imagePullPolicy: IfNotPresent (for local) or Always (for registry)
```

## VS Code Issues

### Extensions Not Working

**Symptoms:**
- Debug features unavailable
- Syntax highlighting missing
- IntelliSense not working

**Solutions:**

1. **Install recommended extensions:**
   ```bash
   # VS Code should prompt when opening folder
   # Or manually install from .vscode/extensions.json
   ```

2. **Verify extensions are enabled:**
   - Open Extensions panel (Ctrl+Shift+X)
   - Search for [extension-name]
   - Ensure "Enabled" (not "Disabled")

3. **Reload VS Code:**
   - Ctrl+Shift+P → "Developer: Reload Window"

### Launch Configuration Not Found

**Symptoms:**
- F5 shows "No configuration found"
- Debug dropdown is empty

**Solutions:**

1. **Open correct folder:**
   ```bash
   # Must open the example folder, not repo root
   code examples/[example-name]
   ```

2. **Verify .vscode/launch.json exists:**
   ```bash
   ls -la .vscode/launch.json
   ```

3. **Check launch.json is valid JSON:**
   - Open `.vscode/launch.json`
   - Look for syntax errors (red squiggles)

## Performance Issues

### Application Runs Slowly in Debug Mode

**Expected Behavior:**
Debug builds are inherently slower:
- Optimizations disabled
- Debugger overhead
- Symbol lookups
- [Language-specific debug overhead]

**This is normal and expected.** Use production builds for performance testing.

**If unusually slow:**

1. **Check resource limits:**
   ```bash
   kubectl top pod -n $NAMESPACE
   # CPU/Memory usage should be reasonable
   ```

2. **Reduce logging verbosity:**
   [Language-specific logging configuration]

3. **Increase resource limits:**
   ```yaml
   resources:
     limits:
       cpu: 1000m
       memory: 1Gi
   ```

### Port-Forward Drops Frequently

**Symptoms:**
- Port-forward keeps disconnecting
- Need to restart ./manage.sh debug often

**Solutions:**

1. **Run in background with reconnect:**
   ```bash
   # Use kubectl with --address and keep alive
   kubectl port-forward -n $NAMESPACE \
     --address 127.0.0.1 \
     pod/[pod-name] [local-port]:[remote-port]
   ```

2. **Check network stability:**
   - VPN issues
   - Wi-Fi disconnections
   - Cluster connection problems

3. **Use a port-forward helper script:**
   [Add script for auto-reconnecting port-forward if applicable]

## Environment-Specific Issues

### Works Locally, Fails in Kubernetes

**Diagnostic Approach:**

1. **Compare environments:**
   ```bash
   # Local
   docker run [image-name]:latest env

   # Kubernetes
   kubectl exec -n $NAMESPACE [pod-name] -- env
   ```

2. **Check for missing config:**
   - Environment variables
   - ConfigMaps
   - Secrets
   - Volume mounts

3. **Network policies:**
   ```bash
   kubectl get networkpolicies -n $NAMESPACE
   ```

### Works in One Cluster, Fails in Another

**Check cluster differences:**

1. **Kubernetes version:**
   ```bash
   kubectl version
   ```

2. **Container runtime:**
   ```bash
   kubectl get nodes -o wide
   # Check CONTAINER-RUNTIME column
   ```

3. **Storage class availability:**
   ```bash
   kubectl get storageclass
   ```

## Language-Specific Issues

### [Language-Specific Issue 1]

**Symptoms:**
[Description]

**Solutions:**
[Solutions specific to this language/framework]

### [Language-Specific Issue 2]

**Symptoms:**
[Description]

**Solutions:**
[Solutions specific to this language/framework]

## Getting Help

### Before Opening an Issue

Gather this information:

```bash
# System info
kubectl version --short
docker version --format '{{.Server.Version}}'
code --version

# Pod info
./manage.sh status
./manage.sh logs --tail 50

# Deployment info
kubectl get deployment -n $NAMESPACE [deployment-name] -o yaml

# Events
kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp'
```

### Opening an Issue

Include:
1. Description of the problem
2. Steps to reproduce
3. Expected vs actual behavior
4. Output from diagnostic commands above
5. VS Code launch.json configuration
6. Dockerfile (if relevant)

### Additional Resources

- [Main repository troubleshooting](../../docs/troubleshooting.md)
- [Language documentation](URL)
- [Debugger documentation](URL)
- [Kubernetes debugging](https://kubernetes.io/docs/tasks/debug/)

## Common Error Messages

### "[Specific error message]"

**Meaning:** [Explanation]

**Solution:** [How to fix]

### "[Specific error message]"

**Meaning:** [Explanation]

**Solution:** [How to fix]

---

**Still stuck?** Open an issue with diagnostic information: [Issue Tracker](https://github.com/nathanfox/k8s-vscode-remote-debug/issues)