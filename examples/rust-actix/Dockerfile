# Build stage
FROM rust:1.83 AS builder

WORKDIR /build

# Copy manifests for dependency caching
COPY Cargo.toml Cargo.lock ./

# Build dependencies only (cached layer)
RUN mkdir src && \
    echo "fn main() {}" > src/main.rs && \
    cargo build && \
    rm -rf src

# Copy source code
COPY src ./src

# Force recompilation (avoid cache issues)
RUN touch src/main.rs

# Build application with debug symbols
RUN cargo build

# Runtime stage
FROM debian:bookworm-slim

WORKDIR /app

# Copy binary from build stage
COPY --from=builder /build/target/debug/rust-actix ./rust-actix

# Expose application port
EXPOSE 8080

# Run application
CMD ["/app/rust-actix"]