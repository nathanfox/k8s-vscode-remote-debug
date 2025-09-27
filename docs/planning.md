# Kubernetes Remote Debugging Examples - Planning Document

## Project Overview

This repository provides working examples of remote debugging for applications running in Kubernetes pods. Each example demonstrates VS Code configuration for attaching from **local VS Code** to a remote process running in a Kubernetes pod, with full debugging capabilities:
- Setting and hitting breakpoints
- Variable inspection and watches
- Step debugging (step over, step into, step out)
- Call stack inspection
- Conditional breakpoints
- Expression evaluation

The primary method is using `kubectl` commands (port-forward or exec) to establish the connection between local VS Code and the remote debugger.

### Development Workflow Philosophy

**Per-Developer Namespace Approach:**
Each developer deploys debug-enabled images to their own Kubernetes namespace (e.g., `dev-alice`, `dev-bob`). This approach provides:
- **Isolation:** Developers can debug without interfering with each other
- **Flexibility:** Each developer can run different versions or configurations
- **Safety:** Breaking changes in one namespace don't affect others
- **Realistic environment:** Debugging in actual Kubernetes environment, not just local Docker
- **Team collaboration:** Shared cluster with isolated workspaces

Example namespace structure:
```
dev-alice/          # Alice's debugging workspace
├── csharp-api
├── python-service
└── nginx-gateway

dev-bob/            # Bob's debugging workspace
├── fsharp-api
├── go-service
└── nginx-gateway
```

## Primary Languages/Frameworks

### .NET Ecosystem
- **C# .NET 8** - ASP.NET Core Web API
- **F# .NET 8** - Giraffe (functional web framework)

### Additional Languages/Frameworks for Evaluation

#### Tier 1 - High Priority
- **Node.js** (Express/Fastify)
  - Very popular for microservices
  - Excellent VS Code debugging support
  - Easy to demonstrate async debugging

- **Python** (FastAPI/Flask)
  - Widely used in data science and web services
  - debugpy has strong VS Code integration
  - Good for showing debugging in async contexts

- **Go**
  - Increasingly popular for cloud-native applications
  - Delve debugger with VS Code support
  - Demonstrates compiled language debugging

#### Tier 2 - Good Examples
- **Rust** (Actix-web/Axum)
  - Growing adoption in systems programming
  - Shows debugging for performance-critical services
  - LLDB integration with VS Code

- **Java** (Spring Boot)
  - Enterprise standard
  - Excellent JVM debugging tools
  - Demonstrates debugging in containerized JVM apps

#### Tier 3 - Specialized/Emerging
- **Elixir** (Phoenix)
  - Functional, concurrent programming model
  - BEAM VM debugging (erlang debugger)
  - Interesting for demonstrating OTP debugging

- **TypeScript** (NestJS/Deno)
  - If separate from Node.js, shows TypeScript-specific debugging
  - Source map handling

- **Ruby** (Rails/Sinatra)
  - Still relevant in many organizations
  - ruby-debug-ide integration

- **Kotlin** (Ktor)
  - Modern JVM language
  - Similar to Java debugging but with Kotlin-specific features

## Repository Structure

```
k8s-vscode-remote-debug/
├── docs/
│   ├── planning.md (this file)
│   ├── debugging-setup-guide.md
│   └── per-developer-namespaces.md
├── examples/
│   ├── csharp-dotnet8-webapi/
│   │   ├── src/
│   │   ├── k8s/
│   │   │   ├── namespace.yaml
│   │   │   ├── deployment.yaml
│   │   │   └── service.yaml
│   │   ├── Dockerfile
│   │   ├── .vscode/
│   │   │   ├── launch.json
│   │   │   └── tasks.json
│   │   ├── manage.sh
│   │   └── README.md
│   ├── fsharp-giraffe-dotnet8/
│   │   └── manage.sh
│   ├── nodejs-express/
│   │   └── manage.sh
│   ├── python-fastapi/
│   │   └── manage.sh
│   ├── go-gin/
│   │   └── manage.sh
│   ├── rust-actix/
│   │   └── manage.sh
│   ├── java-springboot/
│   │   └── manage.sh
│   └── elixir-phoenix/
│       └── manage.sh
├── shared/
│   ├── scripts/
│   │   ├── common-functions.sh
│   │   └── k8s-helpers.sh
│   └── k8s-templates/
│       └── namespace-template.yaml
├── manage.sh (root orchestrator)
└── README.md
```

## Management Script Architecture

Following the pattern from [nginx-dev-gateway](https://github.com/nathanfox/nginx-dev-gateway), this repository uses a **two-tier manage.sh approach**:

### Root manage.sh (Orchestrator)
Located at repository root, provides high-level commands:
```bash
./manage.sh [OPTIONS] COMMAND [ARGS]

OPTIONS:
    -n, --namespace NAMESPACE   Kubernetes namespace (or set NAMESPACE env var)
    -r, --registry REGISTRY     Docker registry URL (or set REGISTRY env var)
    -t, --tag TAG              Docker image tag (default: latest)
    -d, --debug                Enable debug output
    -v, --version              Show version
    -h, --help                 Show this help message

COMMANDS:
    create-ns                  Create developer namespace
    deploy EXAMPLE             Deploy specific example
    deploy-all                 Deploy all examples
    debug EXAMPLE              Setup debugging (port-forward)
    logs EXAMPLE [OPTIONS]     Show logs
        --follow|-f            Follow log output
        --tail N               Number of lines to show
    status                     Show all pods in namespace
    delete                     Delete entire namespace
    list-examples              List available examples
    help                       Show usage
```

**Namespace Resolution:**
Commands resolve namespace in this order:
1. `-n/--namespace` flag (if provided)
2. `NAMESPACE` environment variable
3. Error if neither provided

Example usage:
```bash
# Option 1: Specify namespace with flag
./manage.sh -n dev-alice deploy csharp
./manage.sh --namespace dev-alice debug csharp

# Option 2: Set NAMESPACE environment variable
export NAMESPACE=dev-alice
./manage.sh deploy csharp
./manage.sh debug csharp
./manage.sh logs csharp

# Option 3: Inline environment variable
NAMESPACE=dev-bob ./manage.sh deploy nodejs

# Option 4: Combine with other flags
./manage.sh -n dev-alice -r myregistry.io/org -t v1.0.0 deploy csharp
```

### Per-Example manage.sh
Each example has its own `manage.sh` for example-specific operations:
```bash
cd examples/csharp-dotnet8-webapi
./manage.sh [OPTIONS] COMMAND [ARGS]

OPTIONS:
    -n, --namespace NAMESPACE   Kubernetes namespace (or set NAMESPACE env var)
    -r, --registry REGISTRY     Docker registry URL
    -t, --tag TAG              Docker image tag
    -d, --debug                Enable debug output
    -h, --help                 Show this help message

COMMANDS:
    build                      Build Docker image
    push                       Push image to registry
    deploy                     Deploy to namespace
    debug                      Setup port-forward for debugger
    port-forward [PORT]        Port-forward app port (default: 8080:8080)
    logs [OPTIONS]             Show logs
        --follow|-f            Follow log output
        --tail N               Number of lines to show
    delete                     Delete from namespace
    shell                      Exec into pod
    restart                    Restart deployment
    status                     Show deployment status
    help                       Show this help message
```

Per-example scripts also respect the `NAMESPACE` environment variable with the same resolution order.

### Shared Functions
Common functionality in `shared/scripts/`:
- `common-functions.sh` - Logging, error handling, validation, namespace resolution
- `k8s-helpers.sh` - kubectl wrappers, namespace checks, pod selection

The argument parsing and namespace resolution logic is centralized in `common-functions.sh`:
```bash
# Parse command line arguments for flags like -n, -r, -t, etc.
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -n|--namespace)
                export NAMESPACE="$2"
                shift 2
                ;;
            -r|--registry)
                export REGISTRY="$2"
                shift 2
                ;;
            -t|--tag)
                export IMAGE_TAG="$2"
                shift 2
                ;;
            -d|--debug)
                export DEBUG=1
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                break
                ;;
        esac
    done
    echo "$@"  # Return remaining args (command and its args)
}

# Validate that namespace is set (from flag or env var)
require_namespace() {
    if [ -z "$NAMESPACE" ]; then
        log_error "Namespace not specified. Use -n/--namespace flag or set NAMESPACE env var."
        exit 1
    fi
}
```

### Benefits
- **Consistency** - Same commands across all examples
- **Flexibility** - Per-example customization when needed
- **Convenience** - NAMESPACE env var eliminates repetitive typing
- **Discoverability** - Help commands guide users
- **Error prevention** - Validation built into scripts
- **Namespace safety** - Scripts enforce namespace isolation
- **Developer workflow** - Set NAMESPACE once per session, use everywhere

## Integration with nginx-dev-gateway

The [nginx-dev-gateway](https://github.com/nathanfox/nginx-dev-gateway) project will be used to:
- Route traffic to multiple debug-enabled services
- Demonstrate microservices communication debugging
- Show how to debug distributed tracing scenarios
- Provide a realistic dev environment setup

### Integration Points
- Each example service will be accessible via the nginx gateway
- Gateway configuration examples for routing to debug ports
- Documentation on debugging request flow across services
- Examples of debugging cross-service calls
- Demonstrate debugging in a microservices architecture where requests flow through the gateway
- Root `manage.sh` can orchestrate nginx-dev-gateway deployment alongside examples

## Technical Requirements per Example

Each language/framework example must include:

### 1. Source Code
- Simple REST API with 2-3 endpoints
- At least one endpoint that demonstrates common debugging scenarios:
  - Variable inspection
  - Breakpoint handling
  - Step debugging
  - Conditional breakpoints

### 2. Kubernetes Configuration
- Deployment manifest with debug port exposed
- Service definition
- Namespace creation (per-developer pattern)
- Optional: ConfigMap/Secret for configuration
- Debug-friendly resource limits
- Labels for easy identification (e.g., `developer: alice`)

### 3. Docker Configuration
- Multi-stage Dockerfile (build + runtime)
- Debug-enabled image (separate or configurable)
- Non-root user where applicable
- Health checks

### 4. VS Code Configuration
- `launch.json` with remote attach configuration
- `tasks.json` for common operations (build, deploy, port-forward)
- Recommended extensions list
- Settings for optimal debugging experience

### 5. Documentation
- Prerequisites
- Local setup instructions
- Kubernetes deployment steps (including namespace creation)
- Per-developer namespace configuration
- manage.sh usage for the example
- VS Code debugging setup
- Common troubleshooting
- Debug workflow walkthrough
- Team workflow recommendations

## Debug Strategy per Language

Each language/framework will be evaluated for the best remote debugging method. The goal is to connect **local VS Code** to the remote pod debugger.

### C# / F# (.NET 8)
**Method:** vsdbg (Visual Studio Debugger) + kubectl exec
- **Approach 1 (Preferred):** Use `pipeTransport` in launch.json with `kubectl exec` to pipe debugger communication
- **Approach 2:** Port-forward debug port and attach via TCP
- **Requirements:**
  - vsdbg installed in container
  - Debug symbols available
  - Launch.json configured with `pipeTransport` using kubectl
- **Status:** ✓ Known working method (you've done this before)
- **Test Criteria:** Breakpoints hit, watch variables work, call stack visible

### Node.js
**Method:** Built-in Inspector Protocol + kubectl port-forward
- **Approach:** Start app with `--inspect=0.0.0.0:9229`, port-forward to localhost
- **Requirements:**
  - Node started with `--inspect` or `--inspect-brk`
  - Port 9229 exposed in pod
  - VS Code launch.json configured for remote attach
- **Status:** To evaluate
- **Test Criteria:** Breakpoints in JS code, async call stack, variable inspection

### Python
**Method:** debugpy + kubectl port-forward
- **Approach:** Import debugpy in code, listen on 0.0.0.0:5678, port-forward to localhost
- **Requirements:**
  - debugpy package installed
  - Listen on 0.0.0.0 (not localhost)
  - Launch.json configured for remote attach
- **Status:** To evaluate
- **Test Criteria:** Breakpoints in .py files, watch expressions, exception handling

### Go
**Method:** Delve (dlv) + kubectl port-forward or exec
- **Approach 1:** Run dlv headless in container, port-forward to debug API port (2345)
- **Approach 2:** Use kubectl exec to start dlv and attach
- **Requirements:**
  - Delve installed in container
  - Binary compiled with debug symbols (`-gcflags="all=-N -l"`)
  - VS Code Go extension with dlv support
- **Status:** To evaluate
- **Test Criteria:** Breakpoints in .go files, goroutine inspection, variable watches

### Rust
**Method:** LLDB + kubectl port-forward or gdbserver
- **Approach 1:** Use lldb-server in container, port-forward
- **Approach 2:** Use CodeLLDB extension with remote debugging
- **Requirements:**
  - Debug symbols in binary
  - lldb-server or gdbserver in container
  - CodeLLDB VS Code extension
- **Status:** To evaluate (may be complex)
- **Test Criteria:** Breakpoints in .rs files, inspect Rust types, call stack

### Java (Spring Boot)
**Method:** JDWP + kubectl port-forward
- **Approach:** Start JVM with debug agent, port-forward to 5005
- **Requirements:**
  - JVM args: `-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:5005`
  - Port 5005 exposed
  - VS Code Java Debug extension
- **Status:** To evaluate
- **Test Criteria:** Breakpoints in .java files, hot code replace, expression evaluation

### Elixir (Phoenix)
**Method:** :debugger module + kubectl exec or remote console
- **Approach 1:** Use Erlang's :debugger module with remote connection
- **Approach 2:** IEx remote console with manual debugging
- **Approach 3:** Investigate VS Code ElixirLS debug adapter
- **Requirements:**
  - Erlang debugger module available
  - Remote shell access
  - ElixirLS VS Code extension (if using DAP)
- **Status:** To evaluate (may be challenging)
- **Test Criteria:** Breakpoints in .ex files, process inspection, pattern match debugging

## Debugging Connection Methods

### Method 1: kubectl port-forward (Recommended for most)
```bash
kubectl port-forward pod/my-pod 5000:5000
```
- Simple and reliable
- Works for debuggers that listen on TCP
- Local VS Code connects to localhost:5000
- Best for: Node.js, Python, Java, Go

### Method 2: kubectl exec with pipeTransport (Best for .NET)
```json
"pipeTransport": {
  "pipeCwd": "${workspaceRoot}",
  "pipeProgram": "kubectl",
  "pipeArgs": ["exec", "-i", "my-pod", "--"],
  "debuggerPath": "/vsdbg/vsdbg"
}
```
- Direct stdin/stdout communication
- No port forwarding needed
- Best for: C#, F#

### Method 3: kubectl exec with debug server
```bash
kubectl exec -it my-pod -- dlv attach <pid> --headless --listen=:2345
```
- Start debugger on demand
- Attach to running process
- Best for: Go, potentially Rust

## Evaluation Checklist per Language

For each language/framework, verify:
- [ ] Debugger can be installed/configured in container
- [ ] VS Code can connect from local machine
- [ ] Breakpoints are hit and honored
- [ ] Variable inspection works (locals, watches, hover)
- [ ] Call stack is visible and navigable
- [ ] Step debugging works (over, into, out)
- [ ] Conditional breakpoints function
- [ ] Performance is acceptable (not too slow)
- [ ] Setup is reproducible and documented

## Development Phases

### Phase 1: Core Examples (Primary Focus)
1. C# .NET 8 Web API
2. F# Giraffe .NET 8
3. Documentation framework
4. Base Kubernetes setup

### Phase 2: Popular Languages
1. Node.js (Express)
2. Python (FastAPI)
3. Go (Gin/Echo)

### Phase 3: Additional Languages
1. Rust (Actix-web)
2. Java (Spring Boot)

### Phase 4: Specialized Examples
1. Elixir (Phoenix)
2. Others as needed

### Phase 5: Integration & Polish
1. nginx-dev-gateway integration examples
2. Multi-service debugging scenarios
3. Comprehensive documentation
4. Video tutorials (optional)

## Open Questions

1. ~~Should we provide both debug and production Dockerfiles, or use build args?~~ **DECIDED: Use build args** - Single Dockerfile with `ARG BUILD_MODE=production|debug` for flexibility and maintainability
2. Do we want to demonstrate debugging in:
   - Local Kubernetes (minikube/kind)
   - Remote cluster (cloud provider)
   - Both?
3. Should we include examples of:
   - Debugging tests running in pods?
   - Hot reload/live reload during debugging?
   - Debugging init containers?
4. Do we want to show different debugging scenarios:
   - Memory leaks
   - Performance profiling
   - Async/concurrent code
   - Error handling
5. Should each example be fully self-contained, or share common Kubernetes resources?

## Success Criteria

- Each example can be deployed to a Kubernetes cluster with a single command via manage.sh
- Root manage.sh can orchestrate multiple examples
- Deployment creates or uses per-developer namespace
- VS Code can attach to the running pod and hit breakpoints
- Multiple developers can debug simultaneously in their own namespaces
- Clear documentation that a developer unfamiliar with remote debugging can follow
- Examples run on both local (kind/minikube) and cloud Kubernetes clusters
- Integration with nginx-dev-gateway is documented and functional
- Scripts provided for easy namespace creation and cleanup
- Consistent UX across all examples (same commands, same patterns)

## Next Steps

1. Review and refine this planning document
2. Create repository structure
3. Implement Phase 1 examples (C# and F#)
4. Test debugging workflows
5. Document learnings and refine approach
6. Proceed with additional language examples