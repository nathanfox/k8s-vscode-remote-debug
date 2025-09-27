# Kubernetes Templates

Reusable Kubernetes manifest templates for the remote debugging examples.

## Namespace Template

### File: `namespace-template.yaml`

Template for creating per-developer namespaces with appropriate resource limits and quotas.

**Usage:**
```bash
# Using sed to replace NAMESPACE_NAME
sed 's/NAMESPACE_NAME/dev-alice/g' shared/k8s-templates/namespace-template.yaml | kubectl apply -f -

# Or use the manage.sh script
./manage.sh create-ns -n dev-alice
```

### Labels

All namespaces created from this template include these labels:

| Label | Value | Purpose |
|-------|-------|---------|
| `type` | `dev-namespace` | Identifies developer namespaces for debugging |
| `environment` | `development` | Indicates development environment |
| `managed-by` | `k8s-remote-debug` | Shows namespace is managed by this project |

**Optional labels you may add:**
- `developer: alice` - Associate namespace with a specific developer
- `team: backend` - Group namespaces by team
- `project: payments` - Associate with a project

### Resource Limits

The template includes sensible defaults for development:

**ResourceQuota** (per namespace):
- CPU requests: 4 cores
- Memory requests: 8Gi
- CPU limits: 8 cores
- Memory limits: 16Gi
- PVCs: 5
- Pods: 20

**LimitRange** (per container):
- Default CPU: 500m (request: 100m)
- Default Memory: 512Mi (request: 128Mi)
- Max CPU: 2 cores
- Max Memory: 4Gi
- Min CPU: 50m
- Min Memory: 64Mi

These limits prevent resource exhaustion while allowing reasonable development workloads.

## Labeling Conventions

### Standard Labels for All Resources

Apply these labels consistently across all resources in the repository:

```yaml
labels:
  app: <example-name>              # e.g., csharp-webapi
  framework: <framework>            # e.g., dotnet, nodejs, python
  language: <language>              # e.g., csharp, javascript, python
  debug-enabled: "true"             # Indicates debug configuration
  managed-by: k8s-remote-debug      # Managed by this project
```

### Example-Specific Labels

For deployments and pods in each language example:

**C# .NET 8 Web API:**
```yaml
labels:
  app: csharp-webapi
  framework: dotnet
  language: csharp
  version: "8.0"
  debug-enabled: "true"
```

**F# Giraffe:**
```yaml
labels:
  app: fsharp-giraffe
  framework: giraffe
  language: fsharp
  version: "8.0"
  debug-enabled: "true"
```

**Node.js Express:**
```yaml
labels:
  app: nodejs-express
  framework: express
  language: javascript
  runtime: nodejs
  debug-enabled: "true"
```

**Python FastAPI:**
```yaml
labels:
  app: python-fastapi
  framework: fastapi
  language: python
  debug-enabled: "true"
```

**Go Gin:**
```yaml
labels:
  app: go-gin
  framework: gin
  language: go
  debug-enabled: "true"
```

### Namespace Selection

The `app` label is used by the management scripts to find pods:

```bash
# Find pod by app label
kubectl get pods -n $NAMESPACE -l app=csharp-webapi

# Used internally by k8s-helpers.sh
get_pod_name "$NAMESPACE" "csharp-webapi"
```

### Debug vs Production Differentiation

Use the `debug-enabled` label to distinguish debug-enabled workloads:

```yaml
# Debug deployment
labels:
  debug-enabled: "true"

# Production deployment (for comparison)
labels:
  debug-enabled: "false"
```

### Annotations

Use annotations for descriptive metadata:

```yaml
annotations:
  description: "C# .NET 8 Web API with remote debugging enabled"
  debug-port: "5000"
  debug-protocol: "vsdbg"
  example-url: "https://github.com/nathanfox/k8s-vscode-remote-debug"
```

## Adding New Templates

When adding new template files:

1. Use `TEMPLATE_VARIABLE` naming for placeholders
2. Document all placeholders in this README
3. Include standard labels
4. Add usage examples
5. Update manage.sh if template requires custom handling

## Best Practices

- **Consistent naming**: Use kebab-case for names (e.g., `dev-alice`, `csharp-webapi`)
- **Standard labels**: Always include `app`, `managed-by`, and `debug-enabled`
- **Resource limits**: Set appropriate limits to prevent resource exhaustion
- **Documentation**: Document any custom labels or annotations
- **Validation**: Test templates in both local and cloud Kubernetes environments