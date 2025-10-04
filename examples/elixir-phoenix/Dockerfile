# Elixir Phoenix with Remote Debugging Support
# This Dockerfile supports two debugging approaches:
# 1. Remote - Kubernetes: ElixirLS runs inside the pod (primary method)
# 2. Manual In-Pod: Uses distributed Erlang for IEx remote shell (fallback)

FROM elixir:1.18-alpine AS builder

# Install build dependencies
RUN apk add --no-cache build-base git

WORKDIR /build

# Install hex and rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Copy dependency files
COPY mix.exs mix.lock ./

# Set MIX_ENV for debugging (not production)
ENV MIX_ENV=dev

# Install dependencies
RUN mix deps.get

# Copy application source
COPY config ./config
COPY lib ./lib
COPY priv ./priv

# Compile the application with debug info for remote debugging
RUN mix compile --debug-info

# Runtime stage
FROM elixir:1.18-alpine

# Install runtime dependencies including SSH for Remote - Kubernetes
RUN apk add --no-cache openssl ncurses-libs libstdc++ openssh bash curl git

WORKDIR /app

# Copy from builder
COPY --from=builder /build/_build/dev /app/_build/dev
COPY --from=builder /build/deps /app/deps
COPY --from=builder /build/config /app/config
COPY --from=builder /build/lib /app/lib
COPY --from=builder /build/priv /app/priv
COPY --from=builder /build/mix.exs /app/mix.exs
COPY --from=builder /build/mix.lock /app/mix.lock

# Copy helper script and VS Code config for remote debugging
COPY start_phoenix.exs /app/start_phoenix.exs
COPY .vscode-remote /app/.vscode

# Install hex and rebar in runtime
RUN mix local.hex --force && \
    mix local.rebar --force

# Expose ports:
# - 4000: HTTP
# - 4369: EPMD (Erlang Port Mapper Daemon) - for manual debugging approach
# - 9000: Erlang distribution port - for manual debugging approach
EXPOSE 4000 4369 9000

# Environment variables
ENV MIX_ENV=dev \
    PORT=4000 \
    # Distributed Erlang settings (optional - used for manual debugging)
    RELEASE_NODE=elixir_phoenix@pod.debug \
    RELEASE_COOKIE=debug_cookie_change_me \
    ERL_DIST_PORT=9000 \
    ERL_EPMD_PORT=4369

# Start IEx without auto-starting Phoenix
# - Remote - Kubernetes debugging: VS Code connects via SSH, ElixirLS runs in-pod
# - Manual debugging: Connect via `kubectl exec` with IEx remote shell
# - Distributed Erlang flags support manual debugging approach (optional for Remote - Kubernetes)
CMD iex \
    --name ${RELEASE_NODE} \
    --cookie ${RELEASE_COOKIE} \
    --erl "-kernel inet_dist_listen_min ${ERL_DIST_PORT}" \
    --erl "-kernel inet_dist_listen_max ${ERL_DIST_PORT}" \
    -S mix