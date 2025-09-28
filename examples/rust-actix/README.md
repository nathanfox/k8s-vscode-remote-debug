# Rust Actix-web Debugging Example

This example demonstrates debugging a Rust Actix-web application running in Kubernetes using structured logging with the `tracing` crate.

## Overview

- **Language**: Rust 1.83
- **Framework**: Actix-web 4.11
- **Debugging Method**: Structured logging (`tracing` crate)
- **App Port**: 8080

## Why Tracing Instead of Traditional Debugging?

**TLDR**: LLDB breakpoints don't work reliably with async Rust code in Kubernetes.

We extensively tested LLDB-based remote debugging and found that while the infrastructure works (debugger attachment, breakpoint resolution), **breakpoints never trigger in async functions** running on Tokio's worker threads. This is a fundamental limitation of current debugging tools with Rust's async runtime model.

See the "Appendix: LLDB Investigation" section at the end for details on what we tried.

## Application Structure

```
rust-actix/
├── src/
│   └── main.rs          # Main application with tracing instrumentation
├── Cargo.toml           # Rust dependencies (includes tracing crates)
├── Cargo.lock           # Locked dependency versions
├── Dockerfile           # Multi-stage build
├── k8s/
│   ├── deployment.yaml  # Kubernetes deployment
│   └── service.yaml     # Kubernetes service
└── manage.sh            # Management script
```

## Endpoints

- `GET /health` - Health check endpoint
- `GET /debug-test?count=N` - Test endpoint with loop (demonstrates tracing)
- `GET /weatherforecast` - Weather forecast endpoint with random data

## Quick Start

### Prerequisites

1. Rust toolchain installed (`rustup`)
2. Docker and access to container registry
3. Kubernetes cluster access

### Build and Deploy

```bash
# Set environment variables
export REGISTRY=your-registry.azurecr.io
export NAMESPACE=your-namespace

# Build Docker image
./manage.sh build

# Push to registry
./manage.sh push

# Deploy to Kubernetes
./manage.sh deploy

# Check status
./manage.sh status
```

### Debugging with Tracing

```bash
# Port-forward the application port
./manage.sh port-forward

# In another terminal, make requests
curl http://localhost:8080/health
curl http://localhost:8080/debug-test?count=5
curl http://localhost:8080/weatherforecast

# View logs with tracing output
./manage.sh logs

# Follow logs in real-time
./manage.sh logs -f
```

## Tracing Implementation

The application uses the `tracing` crate for structured logging:

### Setup (main.rs)

```rust
use tracing::{info, debug, instrument};
use tracing_subscriber;

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    // Initialize tracing with debug level
    tracing_subscriber::fmt()
        .with_env_filter("debug")
        .init();

    info!("Starting Rust Actix-web server on 0.0.0.0:8080");
    // ... rest of setup
}
```

### Instrumented Functions

The `#[instrument]` macro automatically logs function entry/exit with arguments:

```rust
#[instrument]
async fn debug_test(query: web::Query<DebugTestQuery>) -> Result<HttpResponse> {
    info!("Debug test called with count={}", query.count);

    for i in 0..query.count {
        debug!("Processing item {}/{}", i + 1, query.count);
        let item = format!("Item {}", i + 1);
        items.push(item);
        thread::sleep(StdDuration::from_millis(10));
    }

    info!("Debug test completed, returning {} items", response.count);
    Ok(HttpResponse::Ok().json(response))
}
```

### Example Output

```
2025-09-28T17:44:34.582173Z  INFO rust_actix: Starting Rust Actix-web server on 0.0.0.0:8080
2025-09-28T17:44:34.582361Z  INFO actix_server::builder: starting 1 workers
2025-09-28T17:45:12.123456Z  INFO rust_actix::debug_test: Debug test called with count=5
2025-09-28T17:45:12.123567Z DEBUG rust_actix::debug_test: Processing item 1/5
2025-09-28T17:45:12.133789Z DEBUG rust_actix::debug_test: Processing item 2/5
2025-09-28T17:45:12.143890Z DEBUG rust_actix::debug_test: Processing item 3/5
2025-09-28T17:45:12.153991Z DEBUG rust_actix::debug_test: Processing item 4/5
2025-09-28T17:45:12.164092Z DEBUG rust_actix::debug_test: Processing item 5/5
2025-09-28T17:45:12.164193Z  INFO rust_actix::debug_test: Debug test completed, returning 5 items
```

## Benefits of Tracing

- ✅ **Works reliably** with async code
- ✅ **Structured data** - Can log complex types with Debug trait
- ✅ **Function instrumentation** - `#[instrument]` automatically logs function entry/exit with arguments
- ✅ **Multiple levels** - info, debug, trace, warn, error
- ✅ **Production-ready** - Can be enabled in production with environment variables
- ✅ **Low setup complexity** - Just add crates and annotations
- ✅ **Zero-cost when disabled** - Compiled out in release builds without env filter

## Docker Build

The Dockerfile uses a **multi-stage build**:

1. **Builder stage** (rust:1.83):
   - Copies `Cargo.toml` and `Cargo.lock`
   - Pre-builds dependencies with dummy `main.rs` (caching layer)
   - **Important**: `RUN touch src/main.rs` before final build to force recompilation
   - Builds the application with debug symbols

2. **Runtime stage** (debian:bookworm-slim):
   - Minimal runtime image
   - Copies only the binary
   - Exposes port 8080

### Cargo Build Caching Issue

**Important**: The Dockerfile includes `RUN touch src/main.rs` before the final build to force Cargo to recompile:

```dockerfile
# Copy source code
COPY src ./src

# Force recompilation (avoid cache issues)
RUN touch src/main.rs

# Build application with debug symbols
RUN cargo build
```

**Why this is needed**: Rust's Cargo has aggressive caching based on file timestamps. When using Docker's multi-stage build with a dummy `fn main() {}` pattern for dependency caching, Cargo can sometimes use stale artifacts from the dependency build phase, resulting in broken binaries that exit immediately.

**This is Rust-specific**: Other languages in this project don't need this workaround:
- Go: Simple compilation, no aggressive caching
- Java/Maven: `mvn clean package` forces clean builds
- Node.js/Python: Interpreted, no compilation caching
- .NET: Build process doesn't have this issue

## Comparison with Other Languages

| Aspect | Rust (Tracing) | Go (Delve) | Java (JDWP) | Node.js (Inspector) |
|--------|----------------|------------|-------------|---------------------|
| Setup Complexity | ✅ Low | ✅ Low | ✅ Medium | ✅ Low |
| Breakpoints | ❌ Not supported | ✅ Full | ✅ Full | ✅ Full |
| Variable Inspection | ⚠️ Via logging | ✅ Interactive | ✅ Interactive | ✅ Interactive |
| Async Debugging | ✅ Full | ✅ Full | ✅ Full | ✅ Full |
| Production Use | ✅ Yes | ⚠️ Limited | ⚠️ Limited | ⚠️ Limited |
| Performance Impact | ⚠️ Some | ⚠️ Significant | ⚠️ Significant | ⚠️ Significant |

## Troubleshooting

### Container Exits Immediately

**Symptom**: Pod enters CrashLoopBackOff, logs are empty

**Solution**: This is the Cargo caching issue. Ensure `RUN touch src/main.rs` is in the Dockerfile before `RUN cargo build`.

### No Tracing Output

**Symptom**: Logs don't show INFO/DEBUG messages

**Causes**:
1. Check tracing initialization in main.rs
2. Verify log level with `./manage.sh logs` (should show debug level)
3. Check if application is running: `./manage.sh status`

### Cannot Connect to Application

**Symptom**: curl commands timeout or connection refused

**Causes**:
1. Port-forward not running: `./manage.sh port-forward`
2. Wrong pod: Check pod name with `./manage.sh status`
3. Application not started: Check logs with `./manage.sh logs`

## Resources

- [Tracing Documentation](https://docs.rs/tracing/)
- [Actix-web Documentation](https://actix.rs/)
- [Rust Debugging Guide](https://github.com/rust-lang/rust/blob/master/src/doc/rustc/src/debugging.md)
- [Tokio Tracing Guide](https://tokio.rs/tokio/topics/tracing)

## Conclusion

This example demonstrates that **structured logging with tracing** is the practical approach for debugging Rust async applications in Kubernetes. While interactive debugging with breakpoints works well in other languages, Rust's async ecosystem isn't yet mature enough for reliable LLDB breakpoints in async code.

**Recommended Approach for Rust in Kubernetes**:

1. **Primary debugging**: Use `tracing` for structured logging
   - Works reliably with async code
   - Production-ready
   - Rich context and structured data

2. **Testing strategy**:
   - Comprehensive unit tests with synchronous test harness
   - Integration tests with test containers
   - Observability (metrics, distributed tracing with OpenTelemetry)

3. **When to use LLDB**: Local development of synchronous code paths only

---

## Found a Solution?

If you discover a way to make LLDB breakpoints work reliably with async Rust code in Kubernetes, **please let us know!**

- Open an issue at: https://github.com/nathanfox/k8s-vscode-remote-debug/issues
- Or submit a PR with your solution

We'd love to update this example if the Rust debugging ecosystem improves. The LLDB setup is documented in the appendix below for future reference.

---

## Appendix: LLDB Investigation

For future reference, here's a summary of our investigation into LLDB-based debugging.

### What We Tried

We attempted to make LLDB breakpoints work with the following approaches:

1. **✗ Regex Breakpoints** (`br set -r '.*debug_test.*closure.*'`)
   - Result: Resolved to 23 locations in framework code, but didn't hit async handler code
   - Issue: Too broad, captured internal Actix-web/Tokio closures instead of handler logic

2. **✗ `breakpointMode: "file"` in launch.json**
   - Result: Changed breakpoint resolution to file-based only
   - Issue: Created unwanted breakpoints in framework files, still didn't hit handlers

3. **✗ Single-threaded Tokio runtime** (`.workers(1)`)
   - Result: Reduced to 1 worker thread, simplified threading model
   - Issue: Even with single thread, async execution on Tokio runtime still bypassed breakpoints

4. **✗ Manual thread selection**
   - Commands: `thread select 3; br set -f src/main.rs -l 53`
   - Result: Breakpoints set on specific worker thread, still `hit count = 0`
   - Issue: Tokio's async task scheduling doesn't map to LLDB's thread tracking

### Technical Details

**What Works**:
- ✅ LLDB infrastructure (lldb-server, gdb-remote protocol)
- ✅ Debugger attachment to running pods
- ✅ Breakpoint resolution (addresses are correct)
- ✅ Thread listing and inspection

**What Doesn't Work**:
- ❌ Breakpoints triggering in async functions/closures
- ❌ Traditional step-through debugging of async code
- ❌ Interactive variable inspection in Tokio worker threads

**Why This Happens**:
- Actix-web uses Tokio for async runtime
- HTTP handlers run as async closures on worker threads
- Worker threads are created dynamically by Tokio
- LLDB's thread tracking doesn't follow Tokio's async execution model
- When `br list` shows breakpoints as "resolved", the addresses are correct, but execution on async tasks doesn't trigger them

### LLDB Setup (For Future Testing)

If Rust async debugging improves in future tooling versions, here's the setup we used:

**Required Files** (not included in this repo):

1. `debug-wrapper.sh`:
```bash
#!/bin/bash
set -e
/app/rust-actix &
APP_PID=$!
echo "Started rust-actix with PID: $APP_PID"
sleep 2
exec lldb-server gdbserver --attach $APP_PID "*:10586"
```

2. `.vscode/launch.json`:
```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Attach to Remote Pod",
      "type": "lldb",
      "request": "attach",
      "targetCreateCommands": [
        "target create ${workspaceFolder}/target/debug/rust-actix"
      ],
      "processCreateCommands": [
        "gdb-remote localhost:10586"
      ],
      "sourceMap": {
        ".": "${workspaceFolder}"
      },
      "stopOnEntry": false
    }
  ]
}
```

3. **Dockerfile changes**:
```dockerfile
# Install lldb-server
RUN apt-get update && \
    apt-get install -y lldb && \
    rm -rf /var/lib/apt/lists/*

# Copy debug wrapper
COPY debug-wrapper.sh ./debug-wrapper.sh
RUN chmod +x ./debug-wrapper.sh

# Expose debug port
EXPOSE 10586

# Run with debugger
CMD ["/app/debug-wrapper.sh"]
```

4. **Deployment changes**:
```yaml
spec:
  securityContext:
    seccompProfile:
      type: Unconfined  # Required for ptrace
  containers:
    securityContext:
      capabilities:
        add:
          - SYS_PTRACE  # Required for debugger
    ports:
      - containerPort: 10586
        name: debug
```

### LLDB Console Commands

```lldb
# List breakpoints
br list

# List threads
thread list

# Select thread
thread select 3

# Set breakpoint
br set -f src/main.rs -l 53

# Continue execution
c

# Step over
n

# Step into
s

# Print variable
p variable_name

# Show backtrace
bt
```

### Related Issues

- [Rust Issue #73522: Debugger support for async/await](https://github.com/rust-lang/rust/issues/73522)
- [LLVM Project: LLDB + Async Rust Issues](https://github.com/llvm/llvm-project/issues/61899)

This is a known limitation of Rust async debugging with LLDB. The Rust debugging ecosystem is still maturing compared to languages like Go, Java, or .NET.