# Rust Remote Debugging Plan

**Status:** 💭 Under Evaluation
**Framework:** Actix-web
**Debugger:** LLDB (lldb-server)
**Complexity:** High
**Priority:** Low-Medium

## Overview

This document outlines the plan for implementing remote debugging for Rust applications in Kubernetes using LLDB. Based on research conducted in September 2024, this is technically feasible but significantly more complex than other language examples in this repository.

## Research Summary

### Debugging Approaches

Two main approaches for remote Rust debugging:

#### 1. lldb-server Platform Mode (More Automated)
```bash
# In container
lldb-server platform --server --listen *:10586
```

**VS Code Configuration:**
```json
{
  "name": "Remote Platform",
  "type": "lldb",
  "request": "launch",
  "program": "${workspaceFolder}/target/debug/app",
  "initCommands": [
    "platform select remote-linux",
    "platform connect connect://localhost:10586"
  ],
  "settings": {
    "target.inherit-env": false
  }
}
```

**Pros:**
- Automatic executable copying to remote
- More integrated workflow
- Better for iterative development

**Cons:**
- Requires full lldb-server platform binary
- More complex initial setup
- May have networking issues in containers

#### 2. gdbserver-style Agent (Simpler)
```bash
# In container
lldb-server gdbserver *:10586 -- /app/app
```

**VS Code Configuration:**
```json
{
  "name": "Remote Attach",
  "type": "lldb",
  "request": "attach",
  "targetCreateCommands": [
    "target create ${workspaceFolder}/target/debug/app"
  ],
  "processCreateCommands": [
    "gdb-remote localhost:10586"
  ]
}
```

**Pros:**
- Simpler configuration
- Similar to Delve/debugpy patterns used in this repo
- Works with standard gdb-remote protocol
- Easier to troubleshoot

**Cons:**
- Manual process management
- Requires local copy of binary for symbols
- Less automated workflow

### Recommended Approach

**Use gdbserver-style agent** - aligns better with patterns established in Go/Python/Node.js examples.

## Implementation Plan

### Phase 1: Basic Setup

#### 1.1 Create Actix-web Application
```rust
// src/main.rs
use actix_web::{web, App, HttpServer, HttpResponse};

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    HttpServer::new(|| {
        App::new()
            .route("/health", web::get().to(health))
            .route("/debug-test", web::get().to(debug_test))
            .route("/weatherforecast", web::get().to(weather_forecast))
    })
    .bind("0.0.0.0:8080")?
    .run()
    .await
}
```

#### 1.2 Dockerfile Configuration

**Multi-stage build:**
```dockerfile
# Build stage
FROM rust:1.75 as builder
WORKDIR /build

# Copy manifests
COPY Cargo.toml Cargo.lock ./

# Build dependencies (cached layer)
RUN mkdir src && \
    echo "fn main() {}" > src/main.rs && \
    cargo build --release && \
    rm -rf src

# Copy source and build
COPY src ./src
RUN cargo build --release

# Runtime stage
FROM debian:bookworm-slim
RUN apt-get update && \
    apt-get install -y lldb && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=builder /build/target/release/app .

EXPOSE 8080 10586

# Run under lldb-server for debugging
CMD ["lldb-server", "gdbserver", "*:10586", "--", "/app/app"]
```

**Key considerations:**
- Debug build: Use `cargo build` (preserves debug symbols)
- Release with debug info: Add to `Cargo.toml`:
  ```toml
  [profile.release]
  debug = true
  ```
- lldb installation: `apt-get install lldb` (Debian/Ubuntu)

### Phase 2: Kubernetes Configuration

#### 2.1 Deployment
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rust-actix
spec:
  template:
    spec:
      containers:
      - name: rust-actix
        image: rust-actix:latest
        ports:
        - containerPort: 8080
          name: http
        - containerPort: 10586
          name: debug
        # Liveness probe disabled for debugging
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
```

#### 2.2 Service
```yaml
apiVersion: v1
kind: Service
metadata:
  name: rust-actix
spec:
  ports:
  - name: http
    port: 8080
    targetPort: 8080
  - name: debug
    port: 10586
    targetPort: 10586
```

### Phase 3: VS Code Configuration

#### 3.1 Extensions
```json
{
  "recommendations": [
    "vadimcn.vscode-lldb",
    "rust-lang.rust-analyzer",
    "ms-kubernetes-tools.vscode-kubernetes-tools"
  ]
}
```

#### 3.2 Launch Configuration
```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Attach to Remote Pod",
      "type": "lldb",
      "request": "attach",
      "targetCreateCommands": [
        "target create ${workspaceFolder}/target/release/app"
      ],
      "processCreateCommands": [
        "gdb-remote localhost:10586"
      ],
      "sourceMap": {
        "/build": "${workspaceFolder}"
      }
    }
  ]
}
```

#### 3.3 Tasks
```json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "cargo-build-debug",
      "type": "shell",
      "command": "cargo build"
    },
    {
      "label": "port-forward-debug",
      "type": "shell",
      "command": "./manage.sh port-forward-debug",
      "isBackground": true
    }
  ]
}
```

### Phase 4: Management Script

```bash
# manage.sh additions

cmd_debug() {
    require_namespace
    check_kubectl

    log_info "Setting up Rust debugging with LLDB..."

    local pod_name="${POD_NAME:-}"
    if [ -z "$pod_name" ]; then
        pod_name=$(get_pod_name "$NAMESPACE" "$APP_NAME")
    fi

    log_info "Port-forwarding LLDB debug port 10586..."
    port_forward_pod "$NAMESPACE" "$pod_name" "10586" "10586"
}
```

## Complexity Analysis

### Comparison with Other Languages

| Aspect | C#/F# | Node.js | Python | Go | **Rust** |
|--------|-------|---------|--------|-----|----------|
| Code changes | ❌ None | ❌ None | ❌ None | ❌ None | ❌ None |
| Build flags | ❌ None | ❌ None | ❌ None | ✅ Required | ⚠️ Optional |
| Debugger install | ✅ vsdbg | ✅ Built-in | ✅ debugpy | ✅ Delve | ⚠️ System pkg |
| VS Code config | 🟢 Simple | 🟢 Simple | 🟢 Simple | 🟡 Medium | 🔴 Complex |
| Path mapping | 🟢 Auto | 🟢 Simple | 🟢 Simple | 🟡 Manual | 🔴 Complex |
| Debug method | kubectl exec | Port-forward | Port-forward | Port-forward | Port-forward |
| Binary size | Medium | Small | Small | Medium | 🔴 Large |
| Setup time | 10 min | 10 min | 10 min | 15 min | 🔴 30+ min |

### Key Challenges

1. **Binary Size**
   - Debug builds: 50-200MB (vs 10-30MB for Go)
   - Impacts image size and deployment time
   - May need separate debug/production images

2. **Complex Configuration**
   - `targetCreateCommands` and `processCreateCommands` required
   - Source path mapping more fragile than other languages
   - May need trial-and-error to get working

3. **LLDB Installation**
   - Not language-specific (system debugger)
   - Adds ~50MB to image
   - Platform-dependent (apt vs yum vs apk)

4. **Path Mapping**
   - Must match build directory structure
   - Sensitive to workspace layout changes
   - Harder to debug path issues

5. **Process Attachment**
   - May require manual PID in some scenarios
   - Less "just works" than other debuggers
   - Requires local binary copy for symbols

6. **Documentation Gaps**
   - Fewer examples for Kubernetes scenarios
   - Most docs focus on local/SSH debugging
   - Limited troubleshooting resources

## Recommendation

### Decision: ⚠️ Defer (Low Priority)

**Reasons:**

**Against immediate implementation:**
- ❌ **Complexity-to-value ratio** - 3x more complex than Go, only incremental learning value
- ❌ **User base** - Smaller Rust adoption compared to Node.js/Python/Go
- ❌ **Time investment** - Likely 2-3 days of debugging edge cases
- ❌ **Maintenance burden** - More brittle, requires platform-specific testing
- ❌ **Consistency** - Breaks pattern of "just works" established by other examples

**For eventual implementation:**
- ✅ **Completeness** - Demonstrates LLDB debugging (only low-level debugger)
- ✅ **Growing ecosystem** - Rust adoption is increasing
- ✅ **Technical interest** - Shows systems-level debugging approach
- ✅ **Actix-web popularity** - Leading Rust web framework

### Alternative Approach

**If implementing, consider:**

1. **"Advanced Examples" section**
   - Group with other complex scenarios
   - Set expectations about difficulty
   - Provide extensive troubleshooting guide

2. **Proof-of-concept first**
   - Build locally to validate workflow
   - Test on kind cluster before documenting
   - Identify pain points early

3. **Hybrid approach**
   - Main example uses debug build (simpler)
   - Optional docs for release-with-debug-info
   - Document both platform and gdbserver modes

4. **Focus on documentation**
   - Extensive troubleshooting section
   - Common path mapping issues
   - Platform-specific notes (Alpine vs Debian vs Ubuntu)

## If Moving Forward

### Success Criteria

- [ ] lldb-server runs in container and listens on 10586
- [ ] Port-forward to debug port works
- [ ] VS Code CodeLLDB extension connects
- [ ] Breakpoints set and hit in Rust source
- [ ] Variable inspection works for Rust types
- [ ] Step debugging functions correctly
- [ ] Source path mapping works consistently
- [ ] Documentation covers common issues
- [ ] Works on both debug and release builds
- [ ] Tested on Alpine and Debian base images

### Estimated Effort

- **Setup and basic example:** 1 day
- **Troubleshooting and refinement:** 1-2 days
- **Documentation:** 1 day
- **Testing across platforms:** 0.5 day
- **Total:** 3.5-4.5 days

Compare to Go (1.5 days) and Node.js (1 day)

## References

- [CodeLLDB Manual](https://github.com/vadimcn/codelldb/blob/master/MANUAL.md)
- [Remote Docker LLDB Setup (2024)](https://patrickwu.space/2024/07/19/setup-remote-docker-lldb/)
- [LLDB Remote Debugging](https://lldb.llvm.org/use/remote.html)
- [Stack Overflow: Remote Rust Debug in VS Code](https://stackoverflow.com/questions/68888706/remote-debug-of-rust-program-in-visual-studio-code)
- [Actix Web Documentation](https://actix.rs/)
- [Rust Web Frameworks Benchmark 2024](https://markaicode.com/rust-web-frameworks-performance-benchmark-2025/)

## Next Steps

1. **Short term:** Document this evaluation in `docs/rust-debugging-plan.md` ✅
2. **Before implementing:** Complete Java and Elixir evaluations
3. **Decision point:** After Phase 8 (nginx-dev-gateway), revisit based on user demand
4. **Alternative:** Accept community contributions for Rust example

## Related Issues

- Binary size optimization strategies
- Multi-stage builds with debug symbols
- LLDB performance in containers
- Alternative: Consider simpler Rust debugging with print statements/logging for demo purposes

---

**Last Updated:** 2025-09-27
**Status:** Planning complete, implementation deferred
**Contact:** See repository issues for questions or to volunteer implementation