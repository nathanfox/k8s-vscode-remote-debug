# Java Spring Boot Remote Debugging Example

Remote debugging example for Java Spring Boot applications running in Kubernetes pods using JDWP (Java Debug Wire Protocol).

## Overview

This example demonstrates how to:
- Build a Docker image with JDWP debugger enabled
- Deploy to Kubernetes with debug port exposed
- Port-forward debug port (5005) from local machine to remote pod
- Attach VS Code debugger using JDWP
- Set breakpoints, inspect variables, and step through Java code

**Language:** Java (v21 LTS)
**Framework:** Spring Boot 3.2.0
**Debugger:** JDWP (Java Debug Wire Protocol)
**Debug Method:** Port-forward to debug port 5005

## Prerequisites

- Kubernetes cluster (local or remote)
- kubectl configured and connected
- Docker for building images
- VS Code with extensions:
  - Extension Pack for Java (vscjava.vscode-java-pack)
  - Kubernetes (ms-kubernetes-tools.vscode-kubernetes-tools)
- Java 21 JDK (for local development)

## Quick Start

```bash
# Set your developer namespace
export NAMESPACE=dev-yourname

# Set your container registry (format depends on provider)
# Azure: your-registry.azurecr.io
# AWS: 123456789012.dkr.ecr.us-east-1.amazonaws.com
# GCP: gcr.io/your-project-id
# Docker Hub: docker.io/yourusername
export REGISTRY=your-registry.azurecr.io

# Build the Docker image
./manage.sh build

# Push to registry
./manage.sh push

# Deploy to Kubernetes
./manage.sh deploy

# Port-forward debug port and attach VS Code debugger
./manage.sh debug

# In VS Code, press F5 to attach debugger
```

## Project Structure

```
java-spring-boot/
├── src/
│   └── main/
│       ├── java/com/example/demo/
│       │   ├── DemoApplication.java       # Spring Boot main class
│       │   ├── controller/                # REST controllers
│       │   │   ├── HealthController.java
│       │   │   ├── DebugTestController.java
│       │   │   └── WeatherForecastController.java
│       │   └── model/                     # Data models
│       │       ├── HealthResponse.java
│       │       ├── DebugTestResponse.java
│       │       └── WeatherForecast.java
│       └── resources/
│           └── application.properties     # Spring Boot configuration
├── pom.xml                                # Maven configuration
├── k8s/                                   # Kubernetes manifests
│   ├── deployment.yaml                    # Deployment with JDWP config
│   └── service.yaml                       # Service definition
├── .vscode/                               # VS Code configuration
│   ├── launch.json                        # Debug configuration (attach via port 5005)
│   ├── tasks.json                         # Build/deploy tasks
│   └── extensions.json                    # Recommended extensions
├── Dockerfile                             # Multi-stage Maven build with JDWP
├── .dockerignore                          # Docker ignore patterns
├── manage.sh                              # Example management script
└── README.md                              # This file
```

## Building the Docker Image

```bash
# Build debug image (with JDWP)
./manage.sh build

# Build with custom tag
./manage.sh -t v1.0.0 build
```

### Docker Configuration

The Dockerfile uses a multi-stage build with Maven for dependency caching:

```dockerfile
# Build stage - Maven compilation
FROM maven:3.9-eclipse-temurin-21 AS builder
WORKDIR /build
COPY pom.xml .
RUN mvn dependency:go-offline
COPY src ./src
RUN mvn clean package -DskipTests

# Runtime stage - Eclipse Temurin JRE
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
COPY --from=builder /build/target/*.jar app.jar
EXPOSE 8080 5005
ENTRYPOINT exec java $JAVA_OPTS -jar app.jar
```

**Key configuration:**
- Multi-stage build separates Maven dependencies for better caching
- `JAVA_OPTS` environment variable allows JDWP configuration at runtime
- Exposes both application port (8080) and debug port (5005)

## Deploying to Kubernetes

```bash
# Deploy with default namespace from env
./manage.sh deploy

# Deploy to specific namespace
./manage.sh -n production deploy

# Check deployment status
./manage.sh status
```

### Kubernetes Configuration

The deployment enables JDWP through the `JAVA_OPTS` environment variable:

```yaml
env:
- name: JAVA_OPTS
  value: "-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:5005 -Xmx384m"
```

**JDWP Parameters:**
- `transport=dt_socket`: Use TCP socket transport
- `server=y`: Act as debug server (not client)
- `suspend=n`: Don't wait for debugger on startup
- `address=*:5005`: Listen on all interfaces, port 5005
- `-Xmx384m`: Limit heap to 384MB (75% of 512Mi container limit)

**Resource Limits:**
```yaml
resources:
  requests:
    memory: "256Mi"
    cpu: "200m"
  limits:
    memory: "512Mi"
    cpu: "1000m"
```

## Remote Debugging

### Start Debug Port-Forward

```bash
# Recommended: Validates pod is ready, then port-forwards debug port (5005)
./manage.sh debug

# Alternative: Just port-forward without validation (faster for re-attachment)
./manage.sh port-forward-debug
```

**Difference:**
- `debug`: Checks pod status before port-forwarding (use for first time or troubleshooting)
- `port-forward-debug`: Immediately port-forwards without validation (use for quick re-attachment)

### Attach VS Code Debugger

1. **Set Breakpoints**: Click in the gutter next to line numbers in your Java files
2. **Start Debugging**: Press `F5` or click "Run" → "Start Debugging"
3. **Trigger Breakpoint**: Make HTTP request to the endpoint

Example breakpoint locations:
- `src/main/java/com/example/demo/controller/DebugTestController.java:28` (inside loop)
- `src/main/java/com/example/demo/controller/WeatherForecastController.java:20` (forecast generation)

### VS Code Debug Configuration

`.vscode/launch.json`:
```json
{
  "name": "Attach to Remote Pod",
  "type": "java",
  "request": "attach",
  "hostName": "localhost",
  "port": 5005,
  "projectName": "demo"
}
```

**Note:** Unlike Go/Node.js, Java debugging does NOT require path mapping. The Java extension automatically handles source file resolution.

## Testing the Application

### Port-Forward Application Port

```bash
# Forward app port 8080
./manage.sh port-forward

# Or specify custom port
./manage.sh port-forward 8081
```

### Test Endpoints

```bash
# Health check
curl http://localhost:8080/health

# Debug test endpoint (good for breakpoints)
curl http://localhost:8080/debug-test?count=5

# Weather forecast
curl http://localhost:8080/weatherforecast

# Spring Boot Actuator health
curl http://localhost:8080/actuator/health
```

## Available Endpoints

| Endpoint | Description |
|----------|-------------|
| `GET /health` | Simple health check |
| `GET /debug-test?count=N` | Loop test (default: 3 iterations, good for debugging) |
| `GET /weatherforecast` | 5-day weather forecast |
| `GET /actuator/health` | Spring Boot Actuator health endpoint |
| `GET /actuator/info` | Application info |

## Management Script Commands

```bash
# Build Docker image
./manage.sh build

# Push to registry
./manage.sh push

# Deploy to Kubernetes
./manage.sh deploy

# Port-forward debug port (5005)
./manage.sh debug
./manage.sh port-forward-debug

# Port-forward app port (8080)
./manage.sh port-forward [PORT]

# View logs
./manage.sh logs
./manage.sh logs --follow
./manage.sh logs --tail 100

# Get shell in pod
./manage.sh shell

# Restart deployment
./manage.sh restart

# Show status
./manage.sh status

# Delete deployment
./manage.sh delete

# Show help
./manage.sh help
```

## Troubleshooting

### Debugger Won't Attach

1. **Check port-forward is running:**
   ```bash
   lsof -i :5005
   ```

2. **Verify JDWP is listening in pod:**
   ```bash
   ./manage.sh shell
   netstat -tlnp | grep 5005
   ```

3. **Check JAVA_OPTS environment variable:**
   ```bash
   kubectl get deployment java-spring-boot -n $NAMESPACE -o yaml | grep JAVA_OPTS
   ```

4. **View pod logs for JDWP startup message:**
   ```bash
   ./manage.sh logs | grep -i "Listening for transport"
   ```

### Breakpoints Not Hitting

1. **Verify source code matches deployed version:**
   - Ensure you've rebuilt and redeployed after code changes
   - Check `./manage.sh status` shows the correct image

2. **Check breakpoint is on executable line:**
   - VS Code shows red circle for active breakpoints
   - Gray circle means breakpoint couldn't bind (wrong line or optimized code)

3. **Verify request reaches the endpoint:**
   ```bash
   ./manage.sh logs --follow
   # Make request in another terminal
   curl http://localhost:8080/debug-test
   ```

### Pod Not Starting

1. **Check pod status:**
   ```bash
   ./manage.sh status
   kubectl describe pod -n $NAMESPACE -l app=java-spring-boot
   ```

2. **View pod logs:**
   ```bash
   ./manage.sh logs --tail 100
   ```

3. **Common issues:**
   - Insufficient memory (JVM requires more than container limit)
   - Image pull errors (check registry authentication)
   - Port conflicts (5005 or 8080 already in use)

### Memory Issues

If the pod is OOMKilled (Out Of Memory):

1. **Increase container memory limit:**
   ```yaml
   resources:
     limits:
       memory: "768Mi"  # Increased from 512Mi
   ```

2. **Adjust JVM heap size proportionally:**
   ```yaml
   env:
   - name: JAVA_OPTS
     value: "-agentlib:jdwp=... -Xmx576m"  # 75% of 768Mi
   ```

## Development Workflow

1. **Make code changes** in your local editor
2. **Build new image**: `./manage.sh build`
3. **Push to registry**: `./manage.sh push`
4. **Restart deployment**: `./manage.sh restart`
5. **Port-forward debug port**: `./manage.sh debug`
6. **Attach debugger** and test

## Additional Resources

- [Spring Boot Documentation](https://docs.spring.io/spring-boot/docs/current/reference/html/)
- [JDWP Specification](https://docs.oracle.com/javase/8/docs/technotes/guides/jpda/jdwp-spec.html)
- [VS Code Java Debugging](https://code.visualstudio.com/docs/java/java-debugging)
- [Eclipse Temurin](https://adoptium.net/)

## Notes

- **JVM Memory Management**: Always set `-Xmx` to ~75% of container memory limit to account for non-heap memory
- **JDWP Performance**: Debug mode has minimal performance impact compared to compiled languages
- **Suspend Mode**: Use `suspend=y` if you need to debug startup code (application waits for debugger)
- **Security**: JDWP port (5005) is NOT exposed externally, only accessible via port-forward
- **Actuator Endpoints**: Additional monitoring endpoints available at `/actuator/*`