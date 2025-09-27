# Kubernetes Remote Debugging Examples

A collection of working examples for remote debugging applications running in Kubernetes pods from local VS Code. This repository demonstrates debugging workflows for multiple languages and frameworks using `kubectl` commands to connect your local development environment to remote processes.

## Overview

This repository provides production-ready examples of remote debugging in Kubernetes, focusing on:

- **Local VS Code to Remote Pod**: Debug processes running in K8s from your local machine
- **Per-Developer Namespaces**: Isolated debugging environments for team collaboration
- **Multiple Languages**: C#, F#, Node.js, Python, Go, and more
- **Consistent Tooling**: Unified `manage.sh` scripts across all examples
- **Real-World Integration**: Works with [nginx-dev-gateway](https://github.com/nathanfox/nginx-dev-gateway) for microservices debugging

## Features

Each example demonstrates:

- ✅ Setting and hitting breakpoints
- ✅ Variable inspection and watches
- ✅ Step debugging (step over, into, out)
- ✅ Call stack navigation
- ✅ Conditional breakpoints
- ✅ Expression evaluation

## Quick Start

```bash
# Set your developer namespace
export NAMESPACE=dev-yourname

# Deploy an example (C# Web API)
./manage.sh -n $NAMESPACE deploy csharp

# Set up debugging (port-forwarding)
./manage.sh -n $NAMESPACE debug csharp

# Open VS Code and start debugging (F5)
# Set breakpoints and attach to the remote pod
```

## Repository Structure

```
k8s-vscode-remote-debug/
├── examples/
│   ├── csharp-dotnet8-webapi/      # C# .NET 8 Web API
│   ├── fsharp-giraffe-dotnet8/     # F# Giraffe Web Framework
│   ├── nodejs-express/              # Node.js with Express
│   ├── python-fastapi/              # Python with FastAPI
│   ├── go-gin/                      # Go with Gin
│   └── ...
├── shared/
│   ├── scripts/                     # Common bash functions
│   └── k8s-templates/              # Reusable K8s manifests
├── docs/
│   ├── planning.md                  # Project planning
│   ├── development-phases.md        # Development roadmap
│   └── ...
└── manage.sh                        # Root management script
```

## Language Examples

| Language | Framework | Debugger | Status |
|----------|-----------|----------|--------|
| C# | .NET 8 Web API | vsdbg | 🚧 In Progress |
| F# | Giraffe .NET 8 | vsdbg | 📋 Planned |
| Node.js | Express | Inspector Protocol | 📋 Planned |
| Python | FastAPI | debugpy | 📋 Planned |
| Go | Gin | Delve | 📋 Planned |
| Rust | Actix-web | LLDB | 💭 Under Evaluation |
| Java | Spring Boot | JDWP | 💭 Under Evaluation |
| Elixir | Phoenix | ElixirLS | 💭 Under Evaluation |

## Prerequisites

- **Kubernetes cluster** (kind, minikube, or cloud provider)
- **kubectl** configured and connected to your cluster
- **Docker** for building images
- **VS Code** with language-specific extensions
- **Namespace access** on your Kubernetes cluster

## Per-Developer Namespace Workflow

This repository promotes a per-developer namespace approach:

```bash
# Each developer has their own namespace
export NAMESPACE=dev-alice

# Deploy your services to your namespace
./manage.sh -n $NAMESPACE deploy-all

# Debug independently without affecting others
./manage.sh -n $NAMESPACE debug csharp
```

**Benefits:**
- **Isolation**: Debug without interfering with teammates
- **Flexibility**: Run different versions/configurations
- **Safety**: Breaking changes stay in your namespace
- **Realistic**: Debug in actual K8s environment

## Integration with nginx-dev-gateway

Works seamlessly with [nginx-dev-gateway](https://github.com/nathanfox/nginx-dev-gateway) to demonstrate microservices debugging:

- Route traffic through nginx gateway to debug-enabled services
- Debug request flow across multiple services
- Switch individual services between debug/stable versions
- Realistic microservices debugging scenarios

See [docs/nginx-gateway-integration.md](docs/nginx-gateway-integration.md) for details (coming soon).

## Management Script Usage

### Root `manage.sh`

```bash
./manage.sh [OPTIONS] COMMAND [ARGS]

OPTIONS:
    -n, --namespace NAMESPACE   Kubernetes namespace
    -r, --registry REGISTRY     Docker registry URL
    -t, --tag TAG              Docker image tag
    -d, --debug                Enable debug output
    -h, --help                 Show help

COMMANDS:
    create-ns                  Create developer namespace
    deploy EXAMPLE             Deploy specific example
    deploy-all                 Deploy all examples
    debug EXAMPLE              Setup debugging (port-forward)
    logs EXAMPLE               Show logs
    status                     Show namespace status
    delete                     Delete namespace
    list-examples              List available examples
```

### Per-Example `manage.sh`

```bash
cd examples/csharp-dotnet8-webapi
./manage.sh [OPTIONS] COMMAND

COMMANDS:
    build                      Build Docker image
    deploy                     Deploy to namespace
    debug                      Setup port-forward for debugger
    logs                       Show logs
    delete                     Delete from namespace
    shell                      Exec into pod
    status                     Show deployment status
```

## Documentation

- [Planning Document](docs/planning.md) - Project architecture and strategy
- [Development Phases](docs/development-phases.md) - Detailed roadmap
- [Per-Developer Namespaces](docs/per-developer-namespaces.md) - Team workflow guide (coming soon)
- [Debugging Setup Guide](docs/debugging-setup-guide.md) - General debugging setup (coming soon)

### Example-Specific Docs

Each example has its own README with:
- Language/framework-specific setup
- Debugging walkthrough
- Troubleshooting guide
- VS Code configuration details

## Common Issues & Best Practices

### Liveness Probes During Debugging

**Issue**: When debugging with breakpoints, your application stops responding to HTTP requests. If you have a liveness probe configured, Kubernetes will kill the pod after the timeout period, causing the debugger to disconnect with exit code 137.

**Symptoms**:
```
Application is shutting down...
Error from pipe program 'kubectl': command terminated with exit code 137
```

**Solution**: All examples in this repository have **liveness probes disabled** for debug deployments:

```yaml
# Liveness probe disabled for debugging to prevent pod restarts when paused at breakpoints
# livenessProbe:
#   httpGet:
#     path: /health
#     port: 8080
```

**Why this works**:
- Readiness probe still runs → pod marked "Not Ready" when paused
- Pod stays alive → debugger connection maintained
- No traffic routed to paused pod → requests not affected
- For production, uncomment liveness probe

### Other Best Practices

- **Use per-developer namespaces** - prevents debug sessions from interfering with teammates
- **Set NAMESPACE env var** - avoids typing `-n` flag repeatedly
- **Keep debug builds separate** - use image tags to distinguish debug/production builds
- **Monitor resource usage** - debug builds use more memory, adjust limits if needed

## Contributing

This is a **reference repository** intended to demonstrate best practices for K8s remote debugging. We recommend **forking** this repository for your own customization.

Contributions are welcome for:
- 🐛 Bug fixes
- 📖 Documentation improvements
- ✨ New language examples (evaluated case-by-case)

See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

## License

[MIT License](LICENSE) - Feel free to use and adapt for your projects.

## Acknowledgments

- Inspired by real-world debugging challenges in Kubernetes environments
- Integrates with [nginx-dev-gateway](https://github.com/nathanfox/nginx-dev-gateway) for microservices patterns
- Built with input from developers debugging across multiple languages and frameworks

## Status

🚧 **Early Development** - Core infrastructure and first examples in progress.

See [Development Phases](docs/development-phases.md) for detailed roadmap.

---

**Questions or Issues?** Open an issue or check the [docs](docs/) folder.