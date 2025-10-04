# Elixir Phoenix Remote Debugging in Kubernetes - Planning Document

- **Created:** 2025-09-30
- **Updated:** 2025-10-04 (Added VS Code Remote - Kubernetes solution)
- **Status:** ✅ COMPLETED - Working solution implemented
- **Language:** Elixir
- **Framework:** Phoenix
- **Debugger:** ElixirLS DAP running inside pod via Remote - Kubernetes extension
- **Note:** Uses memory-optimized configuration to prevent OOM errors

## Objective

Implement remote debugging for Elixir Phoenix applications running in Kubernetes pods, following the established pattern from other language examples (Node.js, Python, Go, Rust, Java).

## Research Findings ✅

### ElixirLS Remote Attach Support (CONFIRMED)

**ANSWER: YES! ElixirLS v0.23.0 (August 2024) supports remote attach!**

1. **ElixirLS Debug Adapter Protocol (DAP) - Remote Attach**
   - VS Code extension: `JakeBecker.elixir-ls` (v0.23.0+)
   - **Supports `request: "attach"` mode** for remote debugging
   - Uses Erlang's built-in `:debugger` and `:int` modules
   - Full breakpoint support, variable inspection, step debugging
   - Configuration example:
   ```json
   {
     "type": "mix_task",
     "name": "attach",
     "request": "attach",
     "projectDir": "${workspaceRoot}",
     "remoteNode": "myapp@remote.host",
     "debugAutoInterpretAllModules": false,
     "debugInterpretModulesPatterns": ["MyApp.*"],
     "env": {
       "ELS_ELIXIR_OPTS": "--sname elixir_ls_dap --cookie mysecret"
     }
   }
   ```

### Additional Debugging Options

2. **Erlang Debugger (`:debugger` module)**
   - Built into Erlang/OTP
   - GUI-based debugger (requires X11)
   - Can debug remote nodes via distributed Erlang
   - Not suitable for VS Code integration

3. **`:int` Module (Interpreter Module)**
   - Low-level debugging capabilities
   - Used by `:debugger` module
   - Can attach to remote nodes
   - Requires code interpretation (performance impact)

4. **IEx Remote Console**
   - `IEx.pry` for breakpoint-like behavior
   - Can attach to remote nodes via distribution
   - Not a traditional debugger but provides inspection capabilities

5. **Distributed Erlang**
   - Core to Elixir's remote debugging capabilities
   - Requires:
     - Node name (`--name` or `--sname`)
     - Erlang cookie (shared secret)
     - Network connectivity between nodes
   - Port 4369 (EPMD - Erlang Port Mapper Daemon)
   - Dynamic port range for distribution (typically 9000-9999)

## Challenges Specific to Elixir

### 1. Distributed Erlang Complexity
- Requires proper node naming and cookie authentication
- Multiple ports needed (EPMD + distribution ports)
- Security concerns with cookie-based auth in K8s

### 2. ElixirLS Remote Attach Limitations
- ElixirLS may not support attaching to already-running remote processes
- Most DAP debuggers expect to launch the process themselves
- Need to investigate if remote attach is possible

### 3. Phoenix Live Reload
- Development mode uses file watching and hot reload
- May conflict with debugging setup
- Need to disable or configure appropriately

### 4. Container Considerations
- Elixir releases vs Mix projects
- Release configuration for remote console access
- EPMD running in container

## Implementation Findings ⚠️

### ElixirLS Remote Attach - DOES NOT WORK

**Implementation attempted on 2025-09-30. Result: FAILED**

**Root Cause:** The Erlang `:int` module (used by ElixirLS for breakpoints) can only interpret modules **before** they are loaded into the VM. Once an Elixir application is running, all modules are already loaded, making it impossible to interpret them for debugging.

**What We Tried:**
1. ✅ ElixirLS v0.29.3 connects to remote node successfully
2. ✅ Compiled modules with `--debug-info` flag
3. ✅ Added `:debugger` to `extra_applications` in mix.exs
4. ✅ Port-forwarding EPMD (4369) and distribution (9000) ports working
5. ✅ ElixirLS attempts to interpret modules via `:int.ni()`
6. ❌ `:int.ni()` returns `:error` - "Invalid beam file or no abstract code"
7. ❌ Breakpoints show as enabled in VS Code but never hit
8. ❌ Attempted pre-interpreting modules before app start - causes recompilation without debug info

**The Fundamental Problem:**
- `:int.ni(Module)` can only interpret modules that haven't been loaded yet
- Phoenix application loads all modules during startup
- Once loaded, modules cannot be interpreted without purging and reloading (which crashes the app)
- This is a limitation of the Erlang VM, not ElixirLS

**Conclusion:** ElixirLS remote attach can connect to remote nodes, but **breakpoints do not work** on already-running applications. This makes it unsuitable for K8s remote debugging.

## Final Implemented Solution ✅

**Manual In-Pod Debugging with Erlang `:int` Module**

### Decision

After attempting multiple approaches, the working solution is **manual debugging inside the pod** using Erlang's `:int` module directly. This approach:
- ✅ Actually works for running Elixir apps in K8s
- ✅ Set real breakpoints at specific line numbers
- ✅ Step through code line by line
- ✅ See current line number while stepping
- ✅ Works with already-running processes (after recompilation inside pod)
- ✅ No code modifications needed (unlike IEx.pry)
- ❌ Not VS Code integrated (terminal-based)
- ❌ Requires exec into pod and manual setup
- ❌ Different workflow than other language examples
- ❌ Cannot directly inspect variables (use `IO.inspect()` in code instead)

### Implementation Strategy (Manual In-Pod Debugging)

1. **Container Setup:**
   - Run Phoenix with distributed Erlang enabled (`--name`, `--cookie`)
   - Expose EPMD (4369) and distribution port (9000)
   - Include Mix and source files in container (dev environment, not release)
   - Add `stdin: true` and `tty: true` to deployment for interactive shell

2. **Debugging Workflow:**
   - **Step 1:** Exec into the running pod: `kubectl exec -it <pod> -- /bin/sh`
   - **Step 2:** Get the Erlang cookie: `echo $RELEASE_COOKIE`
   - **Step 3:** Recompile with debug info inside pod: `cd /app && MIX_ENV=dev mix compile --force --debug-info`
   - **Step 4:** Connect to running node: `iex --name debugger@127.0.0.1 --cookie <cookie> --remsh elixir_phoenix@127.0.0.1`
   - **Step 5:** Start debugger and interpret modules:
     ```elixir
     Application.ensure_all_started(:debugger)
     :int.ni(ElixirPhoenixWeb.ApiController)
     :int.break(ElixirPhoenixWeb.ApiController, 30)
     :int.all_breaks()  # Verify
     ```
   - **Step 6:** Trigger the endpoint (in another terminal): `curl http://localhost:4000/debug-test`
   - **Step 7:** Check if breakpoint was hit: `:int.snapshot()`
   - **Step 8:** Step through code:
     ```elixir
     # Helper to see current line
     current_line = fn ->
       case :int.snapshot() |> Enum.find(fn {_, _, s, _} -> s == :break end) do
         {_pid, _mfa, :break, {_mod, line}} -> "Line #{line}"
         _ -> "Not stopped"
       end
     end

     # Get the stopped process
     {pid, _, _, _} = :int.snapshot() |> Enum.find(fn {_, _, status, _} -> status == :break end)

     # Step through
     :int.step(pid)
     current_line.()

     # Continue
     :int.continue(pid)
     ```
   - **Step 9:** View variable values via `IO.inspect()` in code and watch logs

3. **Variable Inspection:**
   - Add `IO.inspect(variable, label: "Variable Name")` in controller code
   - Watch logs in separate terminal: `kubectl logs -f <pod>`
   - Output appears in logs as code executes

### Why This Works

- `:int` module can interpret modules that are recompiled inside the pod
- Recompilation with `--debug-info` happens before attaching debugger
- Works around the "already-loaded modules" limitation by recompiling in-place
- Standard Erlang debugging capabilities, just manual workflow
- No VS Code integration, but provides functional step debugging

### Old Approach (ElixirLS DAP) - Why It Failed

1. **Container Setup:**
   - Start Phoenix app as a named Erlang node
   - Set Erlang cookie via environment variable
   - Expose EPMD port (4369) and distribution port range

2. **Port Forwarding:**
   - Use `kubectl port-forward` for EPMD (4369) and distribution ports
   - Single command or script to handle multiple ports

3. **VS Code Configuration:**
   - `launch.json` with `request: "attach"` configuration
   - `remoteNode` pointing to the K8s pod node
   - `ELS_ELIXIR_OPTS` with matching cookie and local node name

4. **Debugging Workflow:**
   - Developer sets breakpoints in VS Code
   - Runs port-forward script
   - Presses F5 to attach debugger
   - ElixirLS interprets specified modules on remote node
   - Full step debugging, variable inspection, etc.

### Why This Works

- ElixirLS handles all the complexity of distributed Erlang
- `:int` module interprets code on remote node for breakpoints
- Port-forwarding makes remote node appear local
- Same UX as debugging locally

## Implementation Plan - Completed ✅

### Phase 1: Basic Phoenix Application ✅
- [x] Generate new Phoenix application (JSON API)
- [x] Add sample endpoints (health check, debug-test, weatherforecast)
- [x] Add IO.inspect() statements for variable inspection via logs
- [x] Test locally (ElixirLS debugging failed, manual debugging works)

### Phase 2: Dockerfile with Distributed Erlang ✅
- [x] Base image: `elixir:1.18-alpine`
- [x] Install Hex, Rebar, and dependencies
- [x] Configure to run with `--name` flag for distribution
- [x] Expose EPMD port (4369)
- [x] Expose distribution port (fixed port 9000)
- [x] Set `ERL_DIST_PORT` environment variable
- [x] Pass Erlang cookie via environment variable
- [x] Compile with `--debug-info` flag
- [x] Include source files and Mix in runtime container (dev mode)

### Phase 3: Kubernetes Manifests ✅
- [x] Deployment with:
  - Container ports: 4000 (HTTP), 4369 (EPMD), 9000 (distribution)
  - Environment variables: `RELEASE_NODE`, `RELEASE_COOKIE`, distribution ports
  - `stdin: true` and `tty: true` for interactive shell access
  - Resource limits (256Mi-512Mi memory, 100m-500m CPU)
  - Readiness and liveness probes on `/health`
- [x] Service exposing HTTP port
- [x] Secret for Erlang cookie (created by manage.sh)

### Phase 4: VS Code Debug Configuration ✅ (documented but not functional)
- [x] `.vscode/launch.json` with:
  - `request: "attach"` configuration
  - `remoteNode` parameter
  - `debugInterpretModulesPatterns` for app modules
  - `ELS_ELIXIR_OPTS` with local node name and cookie
  - **Note:** Configuration tested but does not work due to Erlang VM limitations
- [x] `.vscode/tasks.json` for port-forwarding task
- [x] `.vscode/extensions.json` recommending ElixirLS v0.29.0+
- [x] `.vscode/settings.json` with `elixirLS.mixEnv: "dev"`

### Phase 5: Management Scripts ✅
- [x] `manage.sh` script with:
  - `build` - Build Docker image
  - `push` - Push to registry
  - `deploy` - Deploy to K8s (creates secret, applies manifests)
  - `status` - Check deployment status
  - `logs` - Tail pod logs
  - `shell` - Exec into pod for manual debugging
  - `clean` - Remove all resources
- [x] Test all scripts with ACR registry

### Phase 6: Documentation ✅
- [x] README with:
  - Manual in-pod debugging workflow (complete step-by-step)
  - Quick start guide
  - Debugging workflow (exec into pod → recompile → attach → debug)
  - Sample API endpoints
  - Troubleshooting section
  - Architecture explanation (distributed Erlang, :int module)
  - Performance notes (interpreted modules are 10-100x slower)
  - Clear documentation of what works and what doesn't
  - Explanation of why ElixirLS and IEx.pry() don't work
- [x] PLANNING.md with detailed documentation of failed approaches
- [x] All configurations preserved for future testing

### Phase 7: Testing & Validation ✅
- [x] Test breakpoint setting and hitting (manual workflow)
- [x] Test step debugging (`:int.step()`, `:int.continue()`)
- [x] Test viewing current line number while stepping
- [x] Test variable inspection via `IO.inspect()` in logs
- [x] Test with HTTP endpoints (`/debug-test`, `/weatherforecast`)
- [x] Document limitations (no direct variable inspection, no VS Code integration)
- [x] Verify manual debugging workflow works end-to-end

## Key Technical Decisions

1. **Port Configuration:** Use fixed port 9000 for distribution (simpler than dynamic range)
2. **Cookie Management:** Use K8s Secret, mount as env var
3. **Node Names:** Use `--name` with FQDN pattern (e.g., `myapp@127.0.0.1`)
4. **Deployment Style:** Use `mix run --no-halt` for easier debugging (not production release)
5. **Module Interpretation:** Use `debugInterpretModulesPatterns` to limit interpreted modules for performance

## Success Criteria - Final Results

**Initial Goals (VS Code Remote Debugging):**
- [x] Research confirms ElixirLS supports remote attach (v0.23.0+)
- [x] Phoenix app runs in K8s pod with distribution enabled
- [x] VS Code can attach to remote node via ElixirLS
- [❌] Breakpoints work in Phoenix controllers/contexts - **FAILED** (Erlang VM limitation)
- [❌] Variable inspection shows values correctly in VS Code - **FAILED** (Erlang VM limitation)
- [❌] Step debugging works via VS Code - **FAILED** (Erlang VM limitation)
- [x] Documentation is clear and follows repo conventions
- [❌] Example works on first try for developers with ElixirLS installed - **FAILED** (fundamental limitations)

**Revised Goals (Manual In-Pod Debugging):**
- [x] Phoenix app runs in K8s pod with distribution enabled
- [x] Can exec into pod and access IEx remote shell
- [x] Can recompile code with debug info inside pod
- [x] Can set breakpoints at specific line numbers using `:int.break()`
- [x] Breakpoints successfully pause execution
- [x] Can step through code line by line using `:int.step()`
- [x] Can view current line number while stepping
- [x] Can view variable values via `IO.inspect()` in logs
- [x] Can continue execution using `:int.continue()`
- [x] Documentation is comprehensive and accurate
- [x] Manual debugging workflow is fully documented and tested

## Important Notes for Implementation

### ElixirLS Requirements
- Requires ElixirLS v0.23.0 or later
- Must have `:debugger` application available (included in OTP)
- Source files must be available locally (same as remote)

### Distributed Erlang Considerations
- Cookie must match between local and remote nodes
- Node names must be resolvable
- Port-forwarding required for both EPMD (4369) and distribution port (9000)
- Local ElixirLS runs as separate node (e.g., `elixir_ls_dap@127.0.0.1`)

### Performance Impact
- Interpreted modules run ~10-100x slower
- Use `debugInterpretModulesPatterns` to limit scope
- Only interpret app modules, not dependencies
- Consider disabling debugging for performance-critical code paths

### Security Considerations
- Erlang cookies are shared secrets (like passwords)
- Never commit cookies to source control
- Use K8s secrets in production
- Distribution protocol is not encrypted by default (OK for port-forward, not for production)

## References

- [ElixirLS GitHub](https://github.com/elixir-lsp/elixir-ls) - v0.23.0 added remote attach
- [ElixirLS v0.23.0 Release Notes](https://github.com/elixir-lsp/elixir-ls/releases/tag/v0.23.0) - August 2024
- [Erlang Distribution Protocol](https://www.erlang.org/doc/apps/erts/erl_dist_protocol.html)
- [Erlang :int Module](https://www.erlang.org/doc/apps/debugger/int.html) - Code interpretation for debugging
- [ElixirForum: Debugging Remote Node](https://elixirforum.com/t/debugging-a-remote-node-how-was-it-and-what-have-i-learned/39488)
- [Phoenix Deployment Guides](https://hexdocs.pm/phoenix/deployment.html)
- [Debug Adapter Protocol Specification](https://microsoft.github.io/debug-adapter-protocol/)

## Timeline Estimate (Revised)

- Phase 1 (Phoenix App): 1-2 hours
- Phase 2 (Dockerfile): 2-3 hours
- Phase 3 (K8s Manifests): 1-2 hours
- Phase 4 (VS Code Config): 2-3 hours (may require experimentation)
- Phase 5 (Scripts): 1-2 hours
- Phase 6 (Documentation): 2-3 hours
- Phase 7 (Testing): 2-3 hours

**Total:** 11-18 hours

## Risk Assessment

**Medium Risk Areas:**
- ElixirLS remote attach is new (v0.23.0, Aug 2024) - may have undocumented quirks
- Port forwarding EPMD + distribution port simultaneously
- Node naming with port-forward (127.0.0.1 vs actual hostnames)

**Mitigation:**
- Thorough testing of ElixirLS attach workflow
- Provide robust port-forwarding script with error handling
- Clear documentation of troubleshooting steps
- Include fallback to IEx remote shell if ElixirLS fails

**Low Risk Areas:**
- Distributed Erlang is well-established technology
- Phoenix in containers is standard practice
- K8s manifests follow proven patterns from other examples

## Failed Approaches - Documentation for Future Attempts

The following approaches were attempted but failed due to fundamental limitations in Elixir/Erlang or containerized environments. This documentation is preserved for future attempts when new versions of Elixir, ElixirLS, or related tools may resolve these limitations.

### Failed Approach #1: ElixirLS DAP Remote Attach

**Goal:** Use ElixirLS Debug Adapter Protocol to attach VS Code debugger to remote Kubernetes pod, matching the workflow of Node.js, Python, Go, Rust, and Java examples.

**Status:** ❌ FAILED - Fundamental Erlang VM limitation

**Why It Failed:**
- The Erlang `:int` module (used by ElixirLS for breakpoints) can only interpret modules **before** they are loaded into the VM
- Phoenix applications load all modules during startup
- Once loaded, modules cannot be interpreted without purging and reloading (crashes the app)
- This is an Erlang VM limitation, not an ElixirLS bug
- ElixirLS successfully connects to the remote node but cannot set working breakpoints

#### Complete Setup Instructions (for future testing)

**Prerequisites:**
- ElixirLS v0.23.0+ (tested with v0.29.3)
- Elixir 1.18+
- VS Code with ElixirLS extension installed
- Kubernetes cluster with namespace

**Step 1: Dockerfile Configuration**
```dockerfile
FROM elixir:1.18-alpine AS builder

WORKDIR /build
RUN mix local.hex --force && mix local.rebar --force

COPY mix.exs mix.lock ./
ENV MIX_ENV=dev
RUN mix deps.get

COPY config ./config
COPY lib ./lib
COPY priv ./priv

# CRITICAL: Compile with --debug-info flag
RUN mix compile --debug-info

# Runtime stage
FROM elixir:1.18-alpine

WORKDIR /app
COPY --from=builder /build/_build/dev /app/_build/dev
COPY --from=builder /build/deps /app/deps
COPY --from=builder /build/config /app/config
COPY --from=builder /build/lib /app/lib
COPY --from=builder /build/mix.exs /app/mix.exs

RUN mix local.hex --force && mix local.rebar --force

EXPOSE 4000 4369 9000

ENV MIX_ENV=dev \
    RELEASE_NODE=elixir_phoenix@127.0.0.1 \
    RELEASE_COOKIE=debug_cookie_change_me \
    ERL_DIST_PORT=9000

# Start with distributed Erlang
CMD elixir \
    --name ${RELEASE_NODE} \
    --cookie ${RELEASE_COOKIE} \
    --erl "-kernel inet_dist_listen_min ${ERL_DIST_PORT}" \
    --erl "-kernel inet_dist_listen_max ${ERL_DIST_PORT}" \
    -S mix phx.server
```

**Step 2: mix.exs Configuration**
```elixir
def application do
  [
    mod: {ElixirPhoenix.Application, []},
    extra_applications: [:logger, :runtime_tools, :debugger]  # Add :debugger
  ]
end
```

**Step 3: Kubernetes Deployment**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: elixir-phoenix
spec:
  replicas: 1
  template:
    spec:
      containers:
      - name: elixir-phoenix
        image: your-registry/elixir-phoenix:latest
        ports:
        - containerPort: 4000
          name: http
        - containerPort: 4369
          name: epmd
        - containerPort: 9000
          name: debug
        env:
        - name: RELEASE_NODE
          value: "elixir_phoenix@127.0.0.1"
        - name: RELEASE_COOKIE
          valueFrom:
            secretKeyRef:
              name: elixir-phoenix-debug
              key: erlang-cookie
        - name: ERL_DIST_PORT
          value: "9000"
```

**Step 4: VS Code Configuration**

`.vscode/launch.json`:
```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Attach to Remote Pod",
      "type": "mix_task",
      "request": "attach",
      "projectDir": "${workspaceFolder}/examples/elixir-phoenix",
      "remoteNode": "elixir_phoenix@127.0.0.1",
      "debugAutoInterpretAllModules": false,
      "debugInterpretModulesPatterns": [
        "ElixirPhoenix.*",
        "ElixirPhoenixWeb.*"
      ],
      "requireFiles": false,
      "env": {
        "ELS_ELIXIR_OPTS": "--name elixir_ls_dap@127.0.0.1 --cookie debug_cookie_change_me_in_production"
      }
    }
  ]
}
```

`.vscode/settings.json`:
```json
{
  "elixirLS.mixEnv": "dev"
}
```

`.vscode/tasks.json`:
```json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "Port-forward debug ports",
      "type": "shell",
      "command": "kubectl port-forward -n dev-yourname svc/elixir-phoenix 4369:4369 9000:9000",
      "isBackground": true,
      "problemMatcher": []
    }
  ]
}
```

**Step 5: Debugging Workflow**

1. Deploy to Kubernetes: `./manage.sh deploy`
2. Port-forward debug ports:
   ```bash
   kubectl port-forward -n <namespace> svc/elixir-phoenix 4369:4369 9000:9000
   ```
   **Note:** System epmd daemon on port 4369 may conflict. Stop it with:
   ```bash
   sudo systemctl stop epmd
   sudo systemctl mask epmd
   ```
3. In VS Code, set breakpoints in your code
4. Press F5 or start "Attach to Remote Pod" debug configuration
5. ElixirLS will connect to the remote node (you'll see connection success in output)
6. Trigger the endpoint: `curl http://localhost:4000/debug-test`

**Expected Failure:**
- ✅ ElixirLS connects successfully to remote node
- ✅ Port forwarding works
- ✅ Node communication established
- ❌ Breakpoints appear "enabled" in VS Code but are actually inactive
- ❌ ElixirLS logs show: `:int.ni(Module)` returns `:error`
- ❌ Error message: "Invalid beam file or no abstract code"
- ❌ Code never pauses at breakpoints

**Why It Fails:**
ElixirLS tries to call `:int.ni(Module)` to interpret the module, but the module is already loaded in the running Phoenix application. The Erlang VM cannot interpret already-loaded modules without purging them first, which would crash the application.

**What to Try When Testing in Future:**
1. Check if newer ElixirLS versions support pre-interpreted modules
2. Check if Erlang VM adds "hot swap interpretation" capability
3. Test with `debugInterpretModulesPatterns: ["!Elixir.ElixirPhoenix*"]` (negative patterns)
4. Try launching ElixirLS node first, then starting Phoenix from ElixirLS
5. Look for new `:int` module features in Erlang/OTP release notes

---

### Failed Approach #2: IEx.pry() in Container

**Goal:** Use Elixir's built-in `IEx.pry()` to pause execution and attach an interactive debugging session from outside the container.

**Status:** ❌ FAILED - TTY/stdin incompatibility with containers

**Why It Failed:**
- `IEx.pry()` requires an interactive IEx session with proper TTY from application startup
- Even with `stdin: true` and `tty: true` in Kubernetes deployment, the container's IEx process doesn't have the proper TTY setup
- `kubectl exec` and `kubectl attach` cannot provide the required TTY context for IEx.pry()
- Error: "Cannot pry #PID<0.123.0> at Module.function/arity. Is an IEx shell running?"

#### Complete Setup Instructions (for future testing)

**Prerequisites:**
- Elixir 1.18+
- Kubernetes cluster with namespace
- Container with TTY support

**Step 1: Code Modifications**

Add `IEx.pry()` breakpoints in your code:
```elixir
defmodule ElixirPhoenixWeb.ApiController do
  def debug_test(conn, params) do
    count = parse_count(params)

    # Breakpoint here
    require IEx; IEx.pry()

    items = generate_items(count)
    json(conn, %{count: count, items: items})
  end
end
```

**Step 2: Dockerfile Configuration**

Start Phoenix with IEx and enable pry debugging:
```dockerfile
# Use iex instead of elixir
CMD iex \
    --name ${RELEASE_NODE} \
    --cookie ${RELEASE_COOKIE} \
    --erl "-kernel inet_dist_listen_min ${ERL_DIST_PORT}" \
    --erl "-kernel inet_dist_listen_max ${ERL_DIST_PORT}" \
    --dbg pry \
    -S mix phx.server
```

**Step 3: Kubernetes Deployment**

Enable TTY and stdin:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: elixir-phoenix
spec:
  template:
    spec:
      containers:
      - name: elixir-phoenix
        image: your-registry/elixir-phoenix:latest
        stdin: true
        tty: true
        # ... rest of config
```

**Step 4: Debugging Workflow**

1. Deploy: `./manage.sh deploy`
2. Port-forward HTTP: `kubectl port-forward -n <namespace> svc/elixir-phoenix 4000:4000`
3. In one terminal, attach to container:
   ```bash
   kubectl exec -it -n <namespace> <pod-name> -- sh
   # Then inside pod:
   iex --name debugger@127.0.0.1 --cookie <cookie> --remsh elixir_phoenix@127.0.0.1
   ```
   OR try:
   ```bash
   kubectl attach -it -n <namespace> <pod-name>
   ```
4. In another terminal, trigger the endpoint: `curl http://localhost:4000/debug-test`

**Expected Failure:**
- ❌ Request hangs (IEx.pry() is hit but no console appears)
- ❌ Error in logs: "Cannot pry #PID<0.456.0> at ElixirPhoenixWeb.ApiController.debug_test/2. Is an IEx shell running?"
- ❌ `kubectl attach` doesn't provide interactive IEx session
- ❌ `kubectl exec` with `--remsh` connects to node but doesn't catch IEx.pry()

**Why It Fails:**
IEx.pry() requires the main IEx process (the one that started with the application) to be interactive with a proper TTY. In Kubernetes:
- The main process is running in the background without a TTY
- `stdin: true` and `tty: true` allocate a pseudo-TTY but don't make the IEx session interactive
- The IEx.pry() call looks for an interactive session that doesn't exist
- Even `--dbg pry` flag doesn't help because the container's stdin isn't connected to an interactive terminal

**What to Try When Testing in Future:**
1. Check if newer IEx versions support remote pry attachment
2. Try running container with `docker run -it` locally first to verify TTY setup
3. Look for Elixir enhancements to IEx.pry() for containerized environments
4. Test with `kubectl run` with `--stdin --tty` flags (create pod with attached TTY from start)
5. Investigate if Elixir adds "remote pry server" capability
6. Try using `kubectl debug` with ephemeral containers (newer Kubernetes feature)

---

### Failed Approach #3: Pre-Interpreting Modules Before App Start

**Goal:** Interpret modules with `:int` before Phoenix loads them, so ElixirLS can set breakpoints.

**Status:** ❌ FAILED - Modules get recompiled without debug info

**Why It Failed:**
- Created `start_with_debug.exs` script to interpret modules before starting Phoenix
- When modules are interpreted, they get recompiled by Mix
- Recompilation happens without `--debug-info` flag
- Results in modules that are loaded but not debuggable
- Circular dependency: need debug info to interpret, but interpretation triggers recompilation without debug info

#### Setup Attempted

**start_with_debug.exs:**
```elixir
# Start debugger
Application.ensure_all_started(:debugger)

# Interpret modules before they're loaded
:int.ni(ElixirPhoenixWeb.ApiController)
:int.ni(ElixirPhoenixWeb.Router)

# Start Phoenix
Mix.Task.run("phx.server")
```

**Dockerfile change:**
```dockerfile
CMD elixir start_with_debug.exs
```

**Result:** Modules got recompiled without debug info, making them undebuggable.

---

---

## Working Approach #4: VS Code Debugging with Manual Phoenix Startup (Added 2025-10-04)

**Goal:** Achieve VS Code integration with ElixirLS by controlling the timing of when Phoenix loads modules.

**Status:** ✅ WORKS - Provides full VS Code debugging experience

**How It Works:**
The key insight is that ElixirLS remote attach DOES work, but only if modules aren't loaded yet. By preventing Phoenix from auto-starting and manually triggering it after ElixirLS attaches, we get the timing right.

### Implementation

**Step 1: Dockerfile starts IEx without Phoenix**
```dockerfile
# Start IEx but DON'T run phx.server
CMD iex \
    --name ${RELEASE_NODE} \
    --cookie ${RELEASE_COOKIE} \
    --erl "-kernel inet_dist_listen_min ${ERL_DIST_PORT}" \
    --erl "-kernel inet_dist_listen_max ${ERL_DIST_PORT}" \
    -S mix
```

**Step 2: ElixirLS attaches to the waiting IEx node**
- Pod is running with IEx (controllers/routers NOT loaded)
- Port-forward 4369 and 9000
- VS Code F5 to attach ElixirLS
- ElixirLS successfully calls `:int.ni()` on unloaded modules

**Step 3: Manually start Phoenix after attachment**
```bash
./manage.sh -n $NAMESPACE start-phoenix
```

This uses `:rpc.call()` to execute `Mix.Task.run("phx.server")` on the remote node, which loads the (now-interpreted) modules.

### Workflow

```bash
# 1. Deploy
./manage.sh -n dev-yourname deploy

# 2. Port-forward (separate terminal)
./manage.sh -n dev-yourname port-forward-debug

# 3. In VS Code: Set breakpoints and press F5
# ElixirLS attaches and interprets modules

# 4. Start Phoenix (separate terminal or VS Code task)
./manage.sh -n dev-yourname start-phoenix

# 5. Trigger endpoint
curl http://localhost:4000/debug-test

# 6. Debug in VS Code with full breakpoint/variable support!
```

### Why This Works

- ✅ ElixirLS connects to remote node successfully
- ✅ Modules haven't been loaded yet (Phoenix not started)
- ✅ `:int.ni()` succeeds because modules aren't in VM
- ✅ Breakpoints are set on interpreted modules
- ✅ Phoenix starts and loads the interpreted modules
- ✅ Code execution hits breakpoints properly
- ✅ VS Code shows variables, call stack, step debugging works

### Advantages Over Manual In-Pod Debugging

- ✅ Full VS Code integration (GUI debugger)
- ✅ Visual breakpoints (click in gutter)
- ✅ Variables panel shows all values
- ✅ Call stack navigation
- ✅ Watch expressions
- ✅ Debug console for evaluation
- ✅ Standard debug keyboard shortcuts (F5, F10, F11)

### Disadvantages

- ❌ Requires manual Phoenix startup step (not auto-start)
- ❌ More complex workflow than other languages
- ❌ Each pod restart requires repeating the attach process
- ❌ Not suitable for true production debugging (use manual approach instead)

### Configuration Files

**manage.sh** - Added `start-phoenix` command:
```bash
cmd_start_phoenix() {
    # Connect to remote node and execute Mix.Task.run("phx.server")
    kubectl exec -n "$NAMESPACE" "$pod_name" -- \
        elixir --name temp_starter@127.0.0.1 --cookie "$cookie" --eval \
        'Node.connect(:"elixir_phoenix@127.0.0.1") && :rpc.call(:"elixir_phoenix@127.0.0.1", Mix.Task, :run, ["phx.server"])'
}
```

**.vscode/launch.json** - Already configured:
```json
{
  "name": "Attach to Remote Pod",
  "type": "mix_task",
  "request": "attach",
  "remoteNode": "elixir_phoenix@127.0.0.1",
  "debugAutoInterpretAllModules": false,
  "debugInterpretModulesPatterns": ["ElixirPhoenix.*", "ElixirPhoenixWeb.*"]
}
```

**.vscode/tasks.json** - Added `start-phoenix` task for convenience.

---

---

## Working Solution #5: VS Code Remote - Kubernetes Extension (Added 2025-10-04)

**Goal:** Run ElixirLS directly inside the Kubernetes pod to avoid distributed Erlang complexity and module interpretation timing issues.

**Status:** ✅ WORKS PERFECTLY - Best solution for Elixir/Phoenix K8s debugging

**How It Works:**
Uses the [Remote - Kubernetes](https://marketplace.visualstudio.com/items?itemName=okteto.remote-kubernetes) VS Code extension (by Okteto) to connect VS Code to the pod via SSH. ElixirLS runs inside the pod in the same environment as the application.

### Implementation

**Step 1: Add SSH server to Dockerfile**
```dockerfile
# Install SSH and development tools
RUN apk add --no-cache openssh bash curl git && \
    ssh-keygen -A && \
    echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
```

**Step 2: Embed VS Code configuration in Docker image**
```dockerfile
# Copy remote VS Code configuration
COPY .vscode-remote /app/.vscode-remote
```

**Step 3: Create memory-optimized launch.json**

`.vscode-remote/launch.json`:
```json
{
  "type": "mix_task",
  "name": "mix phx.server",
  "request": "launch",
  "task": "phx.server",
  "projectDir": "${workspaceRoot}",
  "debugAutoInterpretAllModules": false,
  "debugInterpretModulesPatterns": [
    "^Elixir\\.ElixirPhoenixWeb\\.ApiController$"
  ],
  "excludeModules": [
    "^Elixir\\.Phoenix\\..*",
    "^Elixir\\.Plug\\..*",
    "^Elixir\\.Bandit\\..*",
    "^Elixir\\.ThousandIsland\\..*",
    // ... all framework modules
  ],
  "requireFiles": [
    "lib/elixir_phoenix_web/controllers/api_controller.ex"
  ],
  "exitAfterTaskReturns": false
}
```

**Step 4: Increase pod memory for ElixirLS overhead**
```yaml
resources:
  requests:
    memory: "1Gi"
  limits:
    memory: "2Gi"
```

### Workflow

```bash
# 1. Deploy
./manage.sh -n dev-yourname deploy

# 2. Install Remote - Kubernetes extension in VS Code
# Extension ID: okteto.remote-kubernetes

# 3. Connect to pod
# Command Palette → "Kubernetes: Attach Visual Studio Code to Pod"
# Select namespace → pod → container

# 4. VS Code reopens connected to pod
# Install ElixirLS extension when prompted

# 5. Open /app folder in remote VS Code

# 6. Set breakpoints in code

# 7. Press F5 to start debugging
# Phoenix compiles and starts with ElixirLS attached

# 8. Trigger endpoint
curl http://localhost:4000/debug-test

# 9. Debug with full VS Code support!
```

### Critical Discovery: Memory Optimization

**Problem:** ElixirLS by default interprets **all modules** in the application (300+ including Phoenix, Plug, Bandit, etc.), causing OOM errors even with 2Gi memory.

**Solution:** Use proper pattern matching with full Elixir atom names:

```json
{
  "debugAutoInterpretAllModules": false,
  "debugInterpretModulesPatterns": [
    "^Elixir\\.ElixirPhoenixWeb\\.ApiController$"  // Only this module!
  ],
  "excludeModules": [
    "^Elixir\\.Phoenix\\..*",     // Exclude all Phoenix modules
    "^Elixir\\.Plug\\..*",        // Exclude all Plug modules
    "^Elixir\\.Bandit\\..*"       // Exclude all Bandit modules
    // etc.
  ]
}
```

**Key points:**
- ElixirLS uses full atom names internally: `Elixir.ModuleName` not `ModuleName`
- Patterns must be anchored: `^Elixir\\.Module$`
- Without this, ElixirLS interprets 300+ modules → OOM crash
- With this, ElixirLS interprets 1 module → works perfectly

### Why This Works

- ✅ ElixirLS runs in same environment as app (no distributed Erlang needed)
- ✅ No module interpretation timing issues
- ✅ Full VS Code integration (breakpoints, variables, stepping)
- ✅ Works with minimal memory when properly configured
- ✅ Configuration embedded in Docker image (automatic setup)
- ✅ Simple workflow (just connect and debug)

### Advantages Over All Other Approaches

**vs. ElixirLS Remote Attach (distributed Erlang):**
- ✅ No distributed Erlang complexity
- ✅ No port-forwarding required
- ✅ No node naming issues
- ✅ No timing problems with module interpretation
- ✅ ElixirLS and app in same environment

**vs. Manual In-Pod Debugging:**
- ✅ Full VS Code GUI (vs terminal commands)
- ✅ Visual breakpoints (vs `:int.break()`)
- ✅ Variables panel (vs `IO.inspect()`)
- ✅ Better developer experience

**vs. Manual Phoenix Startup Approach:**
- ✅ No manual startup step required
- ✅ Simpler workflow
- ✅ Phoenix starts automatically when debugging
- ✅ More like other language examples

### Known Issues and Workarounds

**Issue 1: "undefined variable" errors in debug console**
- These are harmless inspection artifacts from ElixirLS
- Appear when ElixirLS tries to introspect non-existent variables
- Don't affect debugging functionality
- Can be ignored

**Issue 2: OOMKilled without proper configuration**
- Default ElixirLS interprets all modules
- Requires memory-optimized launch.json
- Must use `^Elixir\\.` prefix in patterns
- Must use anchored regex (`^...$`)

**Issue 3: First connection is slow**
- ElixirLS compiles entire project on first run
- Subsequent connections are faster (cache persists)
- Expected behavior, not a bug

### Files Added/Modified

1. **Dockerfile** - Added SSH server and dev tools
2. **.vscode-remote/launch.json** - Memory-optimized debug config
3. **.vscode-remote/extensions.json** - Auto-recommend ElixirLS
4. **k8s/deployment.yaml** - Increased memory to 2Gi
5. **README.md** - Documented Remote - Kubernetes approach
6. **PLANNING.md** - This document

### Performance Impact

- ElixirLS overhead: ~500Mi-1Gi memory
- Interpreted module overhead: ~10-100x slower execution
- With optimized config (1 module): Minimal performance impact
- Without optimization (300+ modules): OOM crash

### Comparison with Other Language Examples

| Language | Debugger Approach | Complexity |
|----------|------------------|------------|
| Node.js | Remote attach via DAP | Low |
| Python | Remote attach via debugpy | Low |
| Go | Delve remote attach | Low |
| Rust | Remote attach via CodeLLDB | Low |
| Java | JDWP remote attach | Low |
| **Elixir** | **Remote - Kubernetes (in-pod)** | **Medium** |

Elixir requires a different approach due to Erlang VM's module interpretation limitations, but the Remote - Kubernetes solution provides comparable developer experience.

---

## Final Decision and Conclusion

✅ **Recommended Solution: VS Code Remote - Kubernetes**

The Remote - Kubernetes extension approach is the best solution for Elixir/Phoenix debugging in Kubernetes because:

1. **Works reliably** - No module interpretation timing issues
2. **Full VS Code integration** - Breakpoints, variables, stepping, etc.
3. **Simple workflow** - Connect to pod → debug
4. **Automatic configuration** - Embedded in Docker image
5. **Memory efficient** - When properly configured
6. **No distributed Erlang** - Avoids complexity and security concerns

**Alternative: Manual In-Pod Debugging** - Still documented for cases where VS Code integration isn't needed.

**Comparison with Other Language Examples:**
- Node.js, Python, Go, Rust, Java: Remote attach via distributed debugger protocol
- Elixir/Phoenix: Remote debugging via in-pod ElixirLS (due to `:int` module limitations)
- Both achieve the same developer experience, just different technical approaches

**Success Criteria (All Achieved):**
- [x] Phoenix app runs in K8s pod
- [x] VS Code can debug remotely
- [x] Breakpoints work in controllers/contexts
- [x] Variable inspection works in VS Code
- [x] Step debugging works (F10/F11/F5)
- [x] Call stack navigation works
- [x] Memory usage is acceptable (2Gi)
- [x] Workflow is straightforward
- [x] Configuration is automatic
- [x] Documentation is clear and comprehensive

**Key Technical Innovation:**
Using `^Elixir\\.ModuleName$` pattern matching to limit ElixirLS module interpretation, preventing OOM errors while maintaining full debugging capabilities. This was the breakthrough that made the Remote - Kubernetes approach viable.