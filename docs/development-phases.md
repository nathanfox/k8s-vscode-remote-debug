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
- [ ] Create `shared/k8s-templates/namespace-template.yaml`
- [ ] Create reusable ConfigMap templates (if needed)
- [ ] Document labeling conventions for per-developer namespaces

#### 1.3 Documentation Templates
- [ ] Create example README template
- [ ] Create debugging workflow template
- [ ] Create troubleshooting guide template

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

## Phase 2: C# .NET 8 Web API Example

**Goal:** Implement first complete example with full debugging workflow

### Tasks

#### 2.1 Application Code
- [ ] Create `examples/csharp-dotnet8-webapi/` structure
- [ ] Initialize .NET 8 Web API project
  - [ ] Create minimal API with 2-3 endpoints
  - [ ] Add endpoint demonstrating debugging scenarios
  - [ ] Add health check endpoint
  - [ ] Configure for containerization

#### 2.2 Docker Configuration
- [ ] Create Dockerfile with multi-stage build
  - [ ] Add `ARG BUILD_MODE` for debug/production
  - [ ] Install vsdbg in debug mode
  - [ ] Configure non-root user
  - [ ] Add health checks
- [ ] Create .dockerignore
- [ ] Test image builds (debug and production modes)

#### 2.3 Kubernetes Manifests
- [ ] Create `k8s/deployment.yaml`
  - [ ] Expose debug port (for vsdbg)
  - [ ] Add appropriate labels
  - [ ] Configure resource limits
  - [ ] Add liveness/readiness probes
- [ ] Create `k8s/service.yaml`
- [ ] Create `k8s/namespace.yaml`

#### 2.4 VS Code Configuration
- [ ] Create `.vscode/launch.json`
  - [ ] Configure pipeTransport with kubectl exec
  - [ ] Add configuration for remote attach
  - [ ] Document pod name requirements
- [ ] Create `.vscode/tasks.json`
  - [ ] Add build task
  - [ ] Add deploy task
  - [ ] Add port-forward task
- [ ] Create `.vscode/extensions.json` with recommended extensions

#### 2.5 Example-Specific manage.sh
- [ ] Create `examples/csharp-dotnet8-webapi/manage.sh`
  - [ ] Implement `build` command
  - [ ] Implement `push` command
  - [ ] Implement `deploy` command
  - [ ] Implement `debug` command (port-forward setup)
  - [ ] Implement `logs` command
  - [ ] Implement `delete` command
  - [ ] Implement `shell` command
  - [ ] Implement `status` command
  - [ ] Add help documentation

#### 2.6 Documentation
- [ ] Create example README.md
  - [ ] Prerequisites
  - [ ] Quick start guide
  - [ ] Detailed debugging workflow
  - [ ] Troubleshooting section
- [ ] Document vsdbg setup
- [ ] Create debugging walkthrough with screenshots

#### 2.7 Testing & Validation
- [ ] Test build process (debug and production)
- [ ] Test deployment to local cluster (kind/minikube)
- [ ] Test VS Code debugging workflow
  - [ ] Verify breakpoints work
  - [ ] Verify variable inspection
  - [ ] Verify step debugging
  - [ ] Verify call stack navigation
  - [ ] Verify conditional breakpoints
- [ ] Test cleanup process
- [ ] Document any issues/learnings

### Deliverables
- Complete, working C# .NET 8 debugging example
- Fully documented debugging workflow
- Template for other language examples

### Success Criteria
- `./manage.sh -n dev-test build` successfully builds debug image
- `./manage.sh -n dev-test deploy` deploys to namespace
- `./manage.sh -n dev-test debug` sets up port-forwarding
- VS Code can attach and hit breakpoints
- Documentation allows unfamiliar developer to debug successfully

---

## Phase 3: F# Giraffe .NET 8 Example

**Goal:** Implement second .NET example, reusing patterns from C#

### Tasks

#### 3.1 Application Code
- [ ] Create `examples/fsharp-giraffe-dotnet8/` structure
- [ ] Initialize F# project with Giraffe framework
  - [ ] Create functional web API with 2-3 routes
  - [ ] Add route demonstrating debugging scenarios
  - [ ] Configure for containerization

#### 3.2 Docker & Kubernetes
- [ ] Create Dockerfile (similar to C# example)
- [ ] Create Kubernetes manifests
- [ ] Adapt for F# specifics

#### 3.3 VS Code & Management
- [ ] Create `.vscode/launch.json` for F#
- [ ] Create `.vscode/tasks.json`
- [ ] Create example-specific `manage.sh`
- [ ] Add F# extensions to recommendations

#### 3.4 Documentation
- [ ] Create example README
- [ ] Document F#-specific debugging considerations
- [ ] Note any differences from C# debugging

#### 3.5 Testing & Validation
- [ ] Test complete debugging workflow
- [ ] Validate all success criteria

### Deliverables
- Complete F# Giraffe debugging example
- Documentation highlighting F# specifics

### Success Criteria
- Same as Phase 2, but for F#
- Document any F#-specific debugging nuances

---

## Phase 4: Node.js Express Example

**Goal:** Implement popular Node.js framework with built-in debugging

### Tasks

#### 4.1 Application Code
- [ ] Create `examples/nodejs-express/` structure
- [ ] Initialize Node.js/Express project
  - [ ] Create REST API with 2-3 endpoints
  - [ ] Add endpoint for debugging demos
  - [ ] Include async/await examples
- [ ] Add package.json with debug scripts

#### 4.2 Docker Configuration
- [ ] Create Dockerfile
  - [ ] Use Node.js base image
  - [ ] Configure `--inspect=0.0.0.0:9229` for debugging
  - [ ] Handle node_modules properly
- [ ] Create .dockerignore

#### 4.3 Kubernetes Manifests
- [ ] Create deployment.yaml (expose port 9229)
- [ ] Create service.yaml
- [ ] Configure for Node.js specifics

#### 4.4 VS Code Configuration
- [ ] Create `.vscode/launch.json`
  - [ ] Configure Node.js attach via port-forward
  - [ ] Test with port 9229
- [ ] Create `.vscode/tasks.json`
- [ ] Add Node.js extensions

#### 4.5 Management & Documentation
- [ ] Create example-specific `manage.sh`
  - [ ] Implement debug command (port-forward to 9229)
- [ ] Create README with Node.js debugging guide
- [ ] Document source map handling (if using TypeScript)

#### 4.6 Testing & Validation
- [ ] Test debugging workflow
- [ ] Validate async debugging
- [ ] Test with breakpoints in callbacks

### Deliverables
- Complete Node.js debugging example
- Documentation for Node.js Inspector Protocol

### Success Criteria
- Port-forward to 9229 works
- VS Code attaches to remote Node process
- Breakpoints hit in async code
- Async call stack visible

---

## Phase 5: Python FastAPI Example

**Goal:** Implement Python debugging with debugpy

### Tasks

#### 5.1 Application Code
- [ ] Create `examples/python-fastapi/` structure
- [ ] Initialize FastAPI project
  - [ ] Create API with 2-3 endpoints
  - [ ] Add async endpoint examples
  - [ ] Configure debugpy integration
- [ ] Create requirements.txt with debugpy

#### 5.2 Docker Configuration
- [ ] Create Dockerfile
  - [ ] Use Python base image
  - [ ] Install debugpy
  - [ ] Configure debugpy to listen on 0.0.0.0:5678
- [ ] Handle virtual environment in container

#### 5.3 Kubernetes Manifests
- [ ] Create deployment.yaml (expose port 5678)
- [ ] Create service.yaml

#### 5.4 VS Code Configuration
- [ ] Create `.vscode/launch.json`
  - [ ] Configure Python attach via port-forward
  - [ ] Set up path mappings
- [ ] Create `.vscode/tasks.json`
- [ ] Add Python extensions

#### 5.5 Management & Documentation
- [ ] Create example-specific `manage.sh`
- [ ] Create README with Python debugging guide
- [ ] Document debugpy setup and configuration

#### 5.6 Testing & Validation
- [ ] Test debugging workflow
- [ ] Validate async debugging
- [ ] Test exception breakpoints

### Deliverables
- Complete Python debugging example
- Documentation for debugpy setup

### Success Criteria
- Port-forward to 5678 works
- VS Code attaches with Python debugger
- Breakpoints work in async code
- Variable inspection works

---

## Phase 6: Go Example

**Goal:** Implement Go debugging with Delve

### Tasks

#### 6.1 Application Code
- [ ] Create `examples/go-gin/` structure
- [ ] Initialize Go project with Gin framework
  - [ ] Create REST API with 2-3 handlers
  - [ ] Add goroutine examples for debugging

#### 6.2 Docker Configuration
- [ ] Create Dockerfile
  - [ ] Install Delve debugger
  - [ ] Compile with debug flags: `-gcflags="all=-N -l"`
  - [ ] Configure dlv headless mode

#### 6.3 Kubernetes Manifests
- [ ] Create deployment.yaml (expose port 2345)
- [ ] Create service.yaml

#### 6.4 VS Code Configuration
- [ ] Create `.vscode/launch.json`
  - [ ] Configure Go attach via Delve
  - [ ] Set up remote debugging
- [ ] Create `.vscode/tasks.json`
- [ ] Add Go extensions

#### 6.5 Management & Documentation
- [ ] Create example-specific `manage.sh`
  - [ ] Add command to start dlv in pod if needed
- [ ] Create README with Go/Delve debugging guide
- [ ] Document goroutine debugging

#### 6.6 Testing & Validation
- [ ] Test debugging workflow
- [ ] Validate goroutine inspection
- [ ] Test with concurrent code

### Deliverables
- Complete Go debugging example
- Documentation for Delve setup

### Success Criteria
- Delve debugger accessible from local VS Code
- Breakpoints work in Go code
- Goroutines visible and inspectable
- Step debugging works

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