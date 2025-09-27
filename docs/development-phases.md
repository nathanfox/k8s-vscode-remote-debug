# Development Phases - K8s Remote Debugging Examples

## Overview

This document outlines the detailed development phases for building out the Kubernetes remote debugging examples repository. Each phase builds upon the previous one, starting with foundational infrastructure and progressing through language-specific implementations.

---

## Phase 0: Repository Foundation

**Goal:** Establish core repository structure and tooling

### Tasks
- [x] Initialize git repository with `develop` branch
- [x] Create planning documentation
- [x] Create repository README with project overview
- [x] Set up basic repository structure (examples/, shared/, docs/)
- [x] Create .gitignore for common artifacts
- [x] Establish contribution guidelines
  - Note: This is a reference repository - recommend users fork for their own customization
  - Contributions welcome primarily for bug fixes and documentation improvements
  - New language/framework examples considered on case-by-case basis

### Deliverables
- Repository structure in place
- Planning documents complete
- README with project description

---

## Phase 1: Shared Infrastructure

**Goal:** Build reusable components used across all examples

### Tasks

#### 1.1 Management Scripts
- [x] Create root `manage.sh` orchestrator
- [x] Implement argument parsing (`-n`, `-r`, `-t`, `-d` flags)
- [x] Implement namespace resolution (flag > env var > error)
- [x] Add command routing to examples
- [x] Implement help system
- [x] Add version information

- [x] Create `shared/scripts/common-functions.sh`
- [x] `parse_args()` - Parse command-line flags
- [x] `require_namespace()` - Validate namespace is set
- [x] `log_info()`, `log_error()`, `log_success()` - Logging functions
- [x] Error handling utilities
- [x] `confirm_action()` - Interactive confirmation
- [x] `wait_for_condition()` - Generic wait helper
- [x] File/directory existence checks

- [x] Create `shared/scripts/k8s-helpers.sh`
- [x] `get_pod_name()` - Find pod by label
- [x] `wait_for_pod_ready()` - Wait for pod to be running
- [x] `wait_for_deployment_ready()` - Wait for deployment
- [x] `port_forward_pod()` - Set up port forwarding
- [x] `check_namespace_exists()` - Validate namespace
- [x] `create_namespace()` - Create namespace with labels
- [x] `delete_namespace()` - Clean up namespace
- [x] `exec_in_pod()` - Execute commands in pod
- [x] `get_pod_logs()` - Retrieve pod logs
- [x] `apply_manifests()` / `delete_manifests()` - Manage K8s resources
- [x] `restart_deployment()` - Restart deployments

- [x] Create automated testing framework
- [x] `tests/test-framework.sh` - Test framework with assertions
- [x] `tests/run-tests.sh` - Test runner (quick/unit/integration/all)
- [x] `tests/unit/test-manage-commands.sh` - Unit tests (10/10 passing)
- [x] `tests/README.md` - Test documentation

#### 1.2 Kubernetes Templates
- [x] Create `shared/k8s-templates/namespace-template.yaml`
- [x] Document labeling conventions for per-developer namespaces
- [x] Create `shared/k8s-templates/README.md` with comprehensive labeling guide
- [x] Include ResourceQuota and LimitRange in namespace template

#### 1.3 Documentation Templates
- [x] Create example README template
- [x] Create debugging workflow template
- [x] Create troubleshooting guide template

### Deliverables
- Functional root `manage.sh` script
- Complete shared function libraries
- K8s manifest templates
- Documentation templates

### Success Criteria
- `./manage.sh help` displays usage
- `./manage.sh create-ns dev-test` creates namespace
- `./manage.sh -n dev-test status` shows namespace status
- NAMESPACE env var is respected

---

## Phase 2: C# .NET 8 Web API Example ✅

**Goal:** Implement first complete example with full debugging workflow

**Status:** COMPLETED (2025-09-27)

### Tasks

#### 2.1 Application Code
- [x] Create `examples/csharp-dotnet8-webapi/` structure
- [x] Initialize .NET 8 Web API project
  - [x] Create minimal API with 3 endpoints (/health, /debug-test, /weatherforecast)
  - [x] Add endpoint demonstrating debugging scenarios
  - [x] Add health check endpoint
  - [x] Configure for containerization

#### 2.2 Docker Configuration
- [x] Create Dockerfile with multi-stage build
  - [x] Add `ARG BUILD_MODE` for debug/production
  - [x] Install vsdbg in debug mode (v18.0.10821.2)
  - [x] Configure non-root user
  - [x] Add health checks
- [x] Create .dockerignore
- [x] Test image builds (debug mode tested and deployed)

#### 2.3 Kubernetes Manifests
- [x] Create `k8s/deployment.yaml`
  - [x] Add appropriate labels (app, framework, language, version, debug-enabled)
  - [x] Configure resource limits (CPU: 100m-500m, Memory: 128Mi-512Mi)
  - [x] Add liveness/readiness probes
- [x] Create `k8s/service.yaml`

#### 2.4 VS Code Configuration
- [x] Create `.vscode/launch.json`
  - [x] Configure pipeTransport with kubectl exec
  - [x] Add configuration for remote attach to vsdbg
  - [x] Configure sourceFileMap for path mapping
  - [x] Use ${env:NAMESPACE} for dynamic pod discovery
- [x] Create `.vscode/tasks.json`
  - [x] Add build task
  - [x] Add deploy task
  - [x] Add port-forward task
- [x] Create `.vscode/extensions.json` with recommended extensions

#### 2.5 Example-Specific manage.sh
- [x] Create `examples/csharp-dotnet8-webapi/manage.sh`
  - [x] Implement `build` command
  - [x] Implement `push` command
  - [x] Implement `deploy` command (with REGISTRY support)
  - [x] Implement `debug` command (verifies pod ready for debugging)
  - [x] Implement `port-forward` command
  - [x] Implement `logs` command
  - [x] Implement `delete` command
  - [x] Implement `shell` command
  - [x] Implement `restart` command
  - [x] Implement `status` command
  - [x] Add help documentation

#### 2.6 Documentation
- [x] Create example README.md
  - [x] Prerequisites
  - [x] Quick start guide
  - [x] Project structure
  - [x] Detailed debugging workflow
  - [x] Troubleshooting section with common issues
- [x] Document vsdbg setup and pipeTransport method
- [x] Create debugging walkthrough with example scenarios

#### 2.7 Testing & Validation
- [x] Test build process (debug mode)
- [x] Test image push to ACR (nfacr.azurecr.io)
- [x] Test deployment to Kubernetes namespace
- [x] Verify all endpoints functional:
  - [x] /health - returns status and timestamp
  - [x] /debug-test?count=N - creates N items
  - [x] /weatherforecast - returns 5-day forecast
- [x] Verify vsdbg installation (version 18.0.10821.2 in /vsdbg/)
- [x] Verify dotnet process running as PID 1
- [x] Test manage.sh commands (status, logs, debug)

### Deliverables
- ✅ Complete, working C# .NET 8 debugging example
- ✅ Fully documented debugging workflow
- ✅ Template for other language examples

### Success Criteria
- ✅ `./manage.sh build` successfully builds debug image
- ✅ `./manage.sh -n nathan deploy` deploys to namespace
- ✅ `./manage.sh -n nathan debug` verifies pod ready for debugging
- ✅ VS Code can attach via pipeTransport (ready for F5 debugging)
- ✅ Documentation provides comprehensive guide for debugging setup

### Notes
- vsdbg uses kubectl exec with pipeTransport (no port-forwarding needed for debugger)
- Application port-forwarding still needed to test endpoints (kubectl port-forward on 8080)
- Successfully tested with Azure Container Registry
- Image substitution in deployment.yaml works correctly with REGISTRY env var

---

## Phase 3: F# Giraffe .NET 8 Example ✅

**Goal:** Implement second .NET example, reusing patterns from C#

**Status:** COMPLETED (2025-09-27)

### Tasks

#### 3.1 Application Code
- [x] Create `examples/fsharp-giraffe-dotnet8/` structure
- [x] Initialize F# project with Giraffe framework
  - [x] Create functional web API with 3 routes (/health, /debug-test, /weatherforecast)
  - [x] Add route demonstrating debugging scenarios
  - [x] Configure for containerization

#### 3.2 Docker & Kubernetes
- [x] Create Dockerfile (similar to C# example, adapted for F#)
- [x] Create Kubernetes manifests with F#-specific labels
- [x] Liveness probe disabled to prevent pod restarts during debugging

#### 3.3 VS Code & Management
- [x] Create `.vscode/launch.json` for F# with input prompts
- [x] Create `.vscode/tasks.json`
- [x] Create example-specific `manage.sh`
- [x] Add F# extensions to recommendations (Ionide-fsharp)

#### 3.4 Documentation
- [x] Create example README with F#-specific sections
- [x] Document F#-specific debugging considerations (functional programming, pipelines, pattern matching)
- [x] Note Giraffe framework specifics (HttpHandler composition)
- [x] Document liveness probe issue and solution

#### 3.5 Testing & Validation
- [x] Test complete debugging workflow
- [x] Built and pushed image to ACR
- [x] Deployed to Kubernetes successfully
- [x] All endpoints verified working
- [x] vsdbg v18.0.10821.2 confirmed installed

### Deliverables
- ✅ Complete F# Giraffe debugging example
- ✅ Documentation highlighting F# specifics and functional debugging
- ✅ Liveness probe issue documented and fixed

### Success Criteria
- ✅ `./manage.sh build` successfully builds F# debug image
- ✅ `./manage.sh -n nathan deploy` deploys to namespace
- ✅ `./manage.sh -n nathan debug` verifies pod ready for debugging
- ✅ VS Code can attach via pipeTransport
- ✅ F#-specific debugging features documented (closures, pipelines, pattern matching)

### Notes
- Reused C# patterns successfully for F# implementation
- Giraffe framework provides functional composition of HTTP handlers
- Same vsdbg debugger works for both C# and F#
- **Critical fix**: Disabled liveness probes in both C# and F# examples
  - Liveness probes kill pods when paused at breakpoints (exit code 137)
  - Solution: Keep readiness probe, disable liveness probe
  - Pod marked "Not Ready" when paused, but stays alive for debugging

---

## Phase 4: Node.js Express Example ✅

**Goal:** Implement popular Node.js framework with built-in debugging

**Status:** COMPLETED (2025-09-27)

### Tasks

#### 4.1 Application Code
- [x] Create `examples/nodejs-express/` structure
- [x] Initialize Node.js/Express project
  - [x] Create REST API with 3 endpoints (/health, /debug-test, /weatherforecast)
  - [x] Add endpoint for debugging demos with async/await
  - [x] Include async/await examples with delay loops
- [x] Add package.json with debug scripts

#### 4.2 Docker Configuration
- [x] Create Dockerfile
  - [x] Use Node.js 22 Alpine base image
  - [x] Configure `--inspect=0.0.0.0:9229` for debugging
  - [x] Handle node_modules properly
- [x] Create .dockerignore

#### 4.3 Kubernetes Manifests
- [x] Create deployment.yaml (expose port 9229)
- [x] Create service.yaml
- [x] Liveness probe disabled to prevent pod restarts during debugging
- [x] Configure for Node.js specifics (labels: framework=express, version="22")

#### 4.4 VS Code Configuration
- [x] Create `.vscode/launch.json`
  - [x] Configure Node.js attach via port-forward
  - [x] Set up port 9229 with localRoot/remoteRoot mapping
- [x] Create `.vscode/tasks.json` (build, deploy, port-forward tasks)
- [x] Add Node.js extensions (ESLint, Kubernetes)

#### 4.5 Management & Documentation
- [x] Create example-specific `manage.sh`
  - [x] Implement debug command (port-forward to 9229)
  - [x] Implement port-forward-debug command
  - [x] Add optional `-p/--pod` flag for pod selection
- [x] Create comprehensive README with Node.js debugging guide (475 lines)
- [x] Document Node.js Inspector Protocol usage
- [x] Document difference from .NET debugging (port-forward vs pipeTransport)

#### 4.6 Testing & Validation
- [x] Test complete debugging workflow
- [x] Built and pushed image to ACR
- [x] Deployed to Kubernetes successfully
- [x] All endpoints verified working
- [x] Node.js Inspector confirmed listening on port 9229
- [x] Validate async debugging with breakpoints
- [x] Test optional `-p/--pod` argument for pod selection

#### 4.7 Pod Selection Enhancement
- [x] Add optional `-p/--pod` flag to `shared/scripts/common-functions.sh`
- [x] Update Node.js manage.sh commands to support pod selection:
  - [x] debug command
  - [x] port-forward-debug command
  - [x] port-forward command
  - [x] logs command
  - [x] shell command
- [x] Update help documentation with example usage
- [x] Test pod selection functionality

### Deliverables
- ✅ Complete Node.js debugging example
- ✅ Documentation for Node.js Inspector Protocol
- ✅ Optional pod selection feature for multi-replica scenarios

### Success Criteria
- ✅ Port-forward to 9229 works
- ✅ VS Code attaches to remote Node process
- ✅ Breakpoints hit in async code
- ✅ Async call stack visible
- ✅ Optional `-p/--pod` flag works for explicit pod selection

### Notes
- Node.js debugging uses port-forward to 9229 (different from .NET's pipeTransport)
- Node.js Inspector Protocol is TCP-based (network connection)
- Requires separate port-forward process running
- Connection reset errors on reconnect are normal and can be ignored
- Added optional pod selection for scenarios with multiple replicas
- Auto-detects first pod if `-p` flag not specified

---

## Phase 5: Python FastAPI Example ✅

**Goal:** Implement Python debugging with debugpy

**Status:** COMPLETED (2025-09-27)

### Tasks

#### 5.1 Application Code
- [x] Create `examples/python-fastapi/` structure
- [x] Initialize FastAPI project
  - [x] Create API with 3 endpoints (/health, /debug-test, /weatherforecast)
  - [x] Add async endpoint examples with asyncio.sleep
  - [x] No debugpy code changes needed - using `python -m debugpy` approach
- [x] Create requirements.txt with debugpy, FastAPI, uvicorn

#### 5.2 Docker Configuration
- [x] Create Dockerfile
  - [x] Use Python 3.12-slim base image
  - [x] Install debugpy via requirements.txt
  - [x] Configure debugpy via CMD: `python -Xfrozen_modules=off -m debugpy --listen 0.0.0.0:5678 -m uvicorn`
  - [x] Added `-Xfrozen_modules=off` to eliminate debugger warnings
- [x] No virtual environment needed in container

#### 5.3 Kubernetes Manifests
- [x] Create deployment.yaml (expose port 5678)
- [x] Create service.yaml
- [x] Liveness probe disabled to prevent pod restarts during debugging

#### 5.4 VS Code Configuration
- [x] Create `.vscode/launch.json`
  - [x] Configure Python attach via port-forward (debugpy type)
  - [x] Set up path mappings (localRoot/remoteRoot)
  - [x] Set justMyCode: false to step into libraries
- [x] Create `.vscode/tasks.json` (build, deploy, port-forward tasks)
- [x] Add Python extensions (ms-python.python, ms-python.debugpy, Kubernetes)

#### 5.5 Management & Documentation
- [x] Create example-specific `manage.sh` with all commands
- [x] Create comprehensive README with Python debugging guide
- [x] Document `python -m debugpy` approach (no code changes required!)
- [x] Document comparison with .NET and Node.js debugging methods
- [x] Added comparison table showing code changes vs other languages

#### 5.6 Testing & Validation
- [x] Test complete debugging workflow
- [x] Built and pushed image to ACR
- [x] Deployed to Kubernetes successfully
- [x] All endpoints verified working
- [x] debugpy confirmed listening on port 5678 (no warnings)
- [x] Validate async debugging with breakpoints

### Deliverables
- ✅ Complete Python debugging example
- ✅ Documentation for debugpy setup with `python -m debugpy` approach
- ✅ Clean logs with no frozen modules warnings

### Success Criteria
- ✅ Port-forward to 5678 works
- ✅ VS Code attaches with Python debugger
- ✅ Breakpoints work in async code
- ✅ Variable inspection works
- ✅ No code changes required (using `-m debugpy` flag)

### Notes
- Python debugging uses `python -m debugpy` approach - **no code changes needed!**
- Similar to Node.js `--inspect` flag, but via module wrapper
- Uses port-forwarding to debug port 5678 (same as Node.js pattern)
- Added `-Xfrozen_modules=off` flag to eliminate Python 3.11+ warnings
- Initially tried embedded debugpy approach, then switched to cleaner `-m debugpy` method
- This approach is more consistent with other language examples (no code pollution)

---

## Phase 6: Go Gin Example ✅

**Goal:** Implement Go debugging with Delve

**Status:** COMPLETED (2025-09-27)

### Tasks

#### 6.1 Application Code
- [x] Create `examples/go-gin/` structure
- [x] Initialize Go project with Gin framework
  - [x] Create REST API with 3 endpoints (/health, /debug-test, /weatherforecast)
  - [x] Add endpoint for debugging with loop and delays
  - [x] Initialize go.mod and go.sum

#### 6.2 Docker Configuration
- [x] Create Dockerfile
  - [x] Multi-stage build (builder + Alpine runtime)
  - [x] Install Delve debugger (latest version)
  - [x] Compile with debug flags: `-gcflags="all=-N -l"`
  - [x] Configure dlv headless mode with `--continue` flag
  - [x] Listen on port 2345, accept multi-client connections

#### 6.3 Kubernetes Manifests
- [x] Create deployment.yaml (expose ports 8080 and 2345)
- [x] Create service.yaml
- [x] Configure readiness probe on /health
- [x] Liveness probe disabled to prevent pod restarts during debugging

#### 6.4 VS Code Configuration
- [x] Create `.vscode/launch.json`
  - [x] Configure Go attach via Delve remote mode
  - [x] Set up `substitutePath` mapping (${workspaceFolder} → /build)
  - [x] Use port 2345 for debugging
- [x] Create `.vscode/tasks.json` (build, deploy, port-forward tasks)
- [x] Add Go extensions (golang.go, Kubernetes)

#### 6.5 Management & Documentation
- [x] Create example-specific `manage.sh` with all commands
- [x] Create comprehensive README with Go/Delve debugging guide
- [x] Document `substitutePath` vs `remotePath` (critical for Go)
- [x] Document Delve installation requirement (`go install dlv@latest`)
- [x] Document build flags and Delve command-line options
- [x] Document troubleshooting for breakpoint binding issues

#### 6.6 Testing & Validation
- [x] Test complete debugging workflow
- [x] Built and pushed image to ACR
- [x] Deployed to Kubernetes successfully
- [x] All endpoints verified working
- [x] Delve confirmed listening on port 2345
- [x] Breakpoints hit correctly after substitutePath fix
- [x] Installed Delve locally for VS Code debugging

### Deliverables
- ✅ Complete Go debugging example
- ✅ Documentation for Delve setup with critical path mapping notes
- ✅ Troubleshooting guide for common Go debugging issues

### Success Criteria
- ✅ Delve debugger accessible from local VS Code via port-forward
- ✅ Breakpoints work in Go code (solid red circles, hit correctly)
- ✅ Variable inspection works
- ✅ Step debugging works
- ✅ Application starts immediately with `--continue` flag

### Notes
- Go debugging uses Delve with port-forwarding (similar to Node.js pattern)
- Requires special build flags `-gcflags="all=-N -l"` to preserve debug symbols
- Uses `substitutePath` (not `remotePath`) for path mapping in VS Code
- Path must map to `/build` (where source files are during Docker build)
- Delve must be installed locally: `go install github.com/go-delve/delve/cmd/dlv@latest`
- Fixed initial breakpoint issue by correcting launch.json path mapping
- Delve runs in headless mode with `--continue` to start app immediately
- Application responds to requests while debugger can attach/detach at any time

---

## Phase 7: Additional Languages (Optional)

### 7.1 Rust (Actix-web)
- [ ] Evaluate LLDB/GDB remote debugging
- [ ] Create example if viable
- [ ] Document complexity vs benefit

### 7.2 Java (Spring Boot)
- [ ] Implement with JDWP
- [ ] Configure JVM debug flags
- [ ] Test hot code replacement

### 7.3 Elixir (Phoenix)
- [ ] Investigate ElixirLS debug adapter
- [ ] Evaluate :debugger module approach
- [ ] Create example if debugging is practical

---

## Phase 8: nginx-dev-gateway Integration

**Goal:** Demonstrate debugging in a microservices architecture

### Tasks

#### 8.1 Integration Documentation
- [ ] Create `docs/nginx-gateway-integration.md`
- [ ] Document how to deploy nginx-dev-gateway alongside examples
- [ ] Explain routing configuration for debug services

#### 8.2 Example Multi-Service Setup
- [ ] Create example configuration with 2-3 services behind gateway
- [ ] Document debugging request flow across services
- [ ] Add example of switching service to debug mode

#### 8.3 Root manage.sh Enhancement
- [ ] Add command to deploy nginx-dev-gateway
- [ ] Add command to configure gateway routes
- [ ] Add command to switch services between debug/stable

#### 8.4 Multi-Service Debugging Scenarios
- [ ] Document debugging service-to-service calls
- [ ] Show debugging with distributed tracing
- [ ] Demonstrate debugging only one service while others run stable

### Deliverables
- Integration documentation
- Example multi-service debugging setup
- Enhanced management scripts

### Success Criteria
- nginx-dev-gateway routes to debug services
- Can debug one service while others run normally
- Request flow debugging works across services

---

## Phase 9: Polish & Documentation

**Goal:** Finalize documentation and repository quality

### Tasks

#### 9.1 Root Documentation
- [ ] Complete main README.md
  - [ ] Project overview
  - [ ] Quick start guide
  - [ ] Link to all examples
  - [ ] Architecture overview
- [ ] Create `docs/per-developer-namespaces.md`
  - [ ] Explain namespace strategy
  - [ ] Document team workflow
  - [ ] Best practices
- [ ] Create `docs/debugging-setup-guide.md`
  - [ ] General debugging setup
  - [ ] kubectl configuration
  - [ ] VS Code setup
- [ ] Create `docs/troubleshooting.md`
  - [ ] Common issues across all examples
  - [ ] Debugging the debugger
  - [ ] Network connectivity issues

#### 9.2 Video/Visual Content (Optional)
- [ ] Create architecture diagrams
- [ ] Record video walkthrough of one example
- [ ] Create animated GIFs for README

#### 9.3 Testing & Quality
- [ ] Test all examples on different K8s clusters
  - [ ] kind
  - [ ] minikube
  - [ ] Cloud provider (GKE/EKS/AKS)
- [ ] Validate all documentation
- [ ] Review all scripts for consistency

#### 9.4 Repository Metadata
- [ ] Add LICENSE file
- [ ] Create CONTRIBUTING.md (if open source)
- [ ] Add GitHub templates (issues, PRs)
- [ ] Add badges to README
- [ ] Create GitHub Actions for CI (optional)

### Deliverables
- Complete, polished repository
- Comprehensive documentation
- Tested across multiple environments

### Success Criteria
- Any developer can follow docs and debug successfully
- All examples work on major K8s distributions
- Documentation is clear and complete

---

## Phase 10: Maintenance & Iteration

**Goal:** Keep repository up-to-date and incorporate feedback

### Ongoing Tasks
- [ ] Monitor for framework/language version updates
- [ ] Update examples as VS Code extensions evolve
- [ ] Address issues and feedback
- [ ] Add new language examples as requested
- [ ] Update nginx-dev-gateway integration as it evolves

---

## Priority Matrix

### High Priority (Must Have)
- Phase 1: Shared Infrastructure
- Phase 2: C# .NET 8 Example
- Phase 3: F# Giraffe Example
- Phase 9: Polish & Documentation

### Medium Priority (Should Have)
- Phase 4: Node.js Example
- Phase 5: Python Example
- Phase 6: Go Example
- Phase 8: nginx-dev-gateway Integration

### Low Priority (Nice to Have)
- Phase 7: Additional Languages
- Video content in Phase 9
- CI/CD automation

---

## Timeline Estimates

**Assuming one developer working part-time:**

- Phase 0: 1 day
- Phase 1: 3-5 days
- Phase 2: 5-7 days (first example is most time-consuming)
- Phase 3: 2-3 days (reuses Phase 2 patterns)
- Phase 4: 3-4 days
- Phase 5: 3-4 days
- Phase 6: 3-4 days
- Phase 8: 2-3 days
- Phase 9: 3-5 days

**Total: 4-6 weeks** for high and medium priority phases

---

## Success Metrics

At completion, this repository will be successful if:

1. ✅ A developer unfamiliar with remote debugging can follow docs and debug within 30 minutes
2. ✅ All examples work on kind, minikube, and cloud K8s
3. ✅ Multiple developers can debug simultaneously in their namespaces
4. ✅ Management scripts provide consistent UX across all examples
5. ✅ Integration with nginx-dev-gateway demonstrates real-world microservices debugging
6. ✅ Repository serves as reference for remote K8s debugging best practices

---

## Notes

- Each phase should be completed on a feature branch and merged to `develop`
- Tag releases after major phases (e.g., v0.1.0 after Phase 2, v0.2.0 after Phase 3)
- Gather feedback after each language example to refine approach
- Document any challenges or learnings in phase completion notes