# Java Spring Boot Implementation Plan

**Priority:** ⭐⭐⭐⭐⭐ CRITICAL
**Status:** Ready for Implementation
**Framework:** Spring Boot 3.x
**Debugger:** JDWP (Java Debug Wire Protocol)
**Estimated Effort:** 2-3 days

## Overview

Implement remote debugging for Java Spring Boot applications running in Kubernetes. This fills the largest gap in current examples (12.7% usage) and provides enterprise-standard Java debugging workflow.

## Technical Approach

### Debugging Method

**JDWP (Java Debug Wire Protocol)**
- Built into JVM (no additional installation needed)
- Industry standard for Java debugging (20+ years mature)
- Port-forward pattern (similar to Node.js, Python, Go)
- Port: 5005 (standard JDWP port)

### Application Structure

**Framework:** Spring Boot 3.2.x (latest stable)
**Java Version:** 17 or 21 (LTS versions)
**Build Tool:** Maven (more common than Gradle)

**Project Structure:**
```
examples/java-spring-boot/
├── src/
│   └── main/
│       ├── java/
│       │   └── com/
│       │       └── example/
│       │           └── demo/
│       │               ├── DemoApplication.java
│       │               ├── controller/
│       │               │   ├── HealthController.java
│       │               │   ├── DebugTestController.java
│       │               │   └── WeatherForecastController.java
│       │               └── model/
│       │                   ├── HealthResponse.java
│       │                   ├── DebugTestResponse.java
│       │                   └── WeatherForecast.java
│       └── resources/
│           └── application.properties
├── k8s/
│   ├── deployment.yaml
│   └── service.yaml
├── .vscode/
│   ├── launch.json
│   ├── tasks.json
│   └── extensions.json
├── Dockerfile
├── .dockerignore
├── pom.xml
├── manage.sh
└── README.md
```

## Phase 1: Application Code

### 1.1 Spring Boot Application

**pom.xml dependencies:**
```xml
<dependencies>
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-web</artifactId>
    </dependency>
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-actuator</artifactId>
    </dependency>
</dependencies>
```

**application.properties:**
```properties
server.port=8080
management.endpoints.web.exposure.include=health
management.endpoint.health.show-details=always
```

### 1.2 Endpoints

**1. Health Endpoint** - `/health` (GET)
```java
@GetMapping("/health")
public HealthResponse health() {
    return new HealthResponse(
        "healthy",
        Instant.now().toString()
    );
}
```

**2. Debug Test Endpoint** - `/debug-test` (GET)
- Query parameter: `count` (default: 3, range: 1-20)
- Creates list of items with delays for debugging
```java
@GetMapping("/debug-test")
public DebugTestResponse debugTest(@RequestParam(defaultValue = "3") int count) {
    List<String> items = new ArrayList<>();
    for (int i = 0; i < count; i++) {
        items.add("Item " + (i + 1));
        Thread.sleep(10); // Good breakpoint location
    }
    return new DebugTestResponse(count, items, Instant.now().toString());
}
```

**3. Weather Forecast Endpoint** - `/weatherforecast` (GET)
- Returns 5-day weather forecast
```java
@GetMapping("/weatherforecast")
public List<WeatherForecast> weatherForecast() {
    String[] summaries = {"Freezing", "Bracing", "Chilly", "Cool", "Mild",
                          "Warm", "Balmy", "Hot", "Sweltering", "Scorching"};
    List<WeatherForecast> forecasts = new ArrayList<>();
    Random random = new Random();

    for (int i = 1; i <= 5; i++) {
        LocalDate date = LocalDate.now().plusDays(i);
        int tempC = random.nextInt(76) - 20;
        forecasts.add(new WeatherForecast(
            date.toString(),
            tempC,
            32 + (tempC * 9 / 5),
            summaries[random.nextInt(summaries.length)]
        ));
    }
    return forecasts;
}
```

## Phase 2: Docker Configuration

### 2.1 Multi-Stage Dockerfile

```dockerfile
# Build stage
FROM maven:3.9-eclipse-temurin-21 AS builder
WORKDIR /build

# Copy pom.xml and download dependencies (cached layer)
COPY pom.xml .
RUN mvn dependency:go-offline

# Copy source and build
COPY src ./src
RUN mvn clean package -DskipTests

# Runtime stage
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app

# Copy JAR from build stage
COPY --from=builder /build/target/*.jar app.jar

# Expose application and debug ports
EXPOSE 8080 5005

# Run with JDWP enabled via JAVA_OPTS
ENTRYPOINT exec java $JAVA_OPTS -jar app.jar
```

**Key points:**
- Multi-stage build reduces final image size
- Maven downloads dependencies in separate layer (caching)
- `JAVA_OPTS` environment variable for JDWP configuration
- Uses `exec` to ensure proper signal handling

### 2.2 JDWP Configuration

**Environment variable in Kubernetes:**
```yaml
env:
- name: JAVA_OPTS
  value: "-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:5005"
```

**JDWP parameters explained:**
- `transport=dt_socket`: Use TCP socket transport
- `server=y`: JVM listens for debugger (vs connecting to debugger)
- `suspend=n`: Start application immediately (don't wait for debugger)
- `address=*:5005`: Bind to all interfaces on port 5005 (Java 9+ syntax)

**Note:** Before Java 9, use `address=5005`. Java 9+ requires `*:5005` for remote access.

## Phase 3: Kubernetes Configuration

### 3.1 Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: java-spring-boot
  labels:
    app: java-spring-boot
    framework: spring-boot
    language: java
    version: "21"
    debug-enabled: "true"
spec:
  replicas: 1
  selector:
    matchLabels:
      app: java-spring-boot
  template:
    metadata:
      labels:
        app: java-spring-boot
        framework: spring-boot
        language: java
        version: "21"
        debug-enabled: "true"
    spec:
      containers:
      - name: java-spring-boot
        image: java-spring-boot:latest
        ports:
        - containerPort: 8080
          name: http
          protocol: TCP
        - containerPort: 5005
          name: debug
          protocol: TCP
        env:
        - name: JAVA_OPTS
          value: "-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:5005"
        resources:
          requests:
            memory: "256Mi"
            cpu: "200m"
          limits:
            memory: "512Mi"
            cpu: "1000m"
        # Liveness probe disabled for debugging to prevent pod restarts when paused at breakpoints
        # livenessProbe:
        #   httpGet:
        #     path: /actuator/health
        #     port: 8080
        #   initialDelaySeconds: 30
        #   periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /actuator/health
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 10
```

**Key considerations:**
- **Higher memory:** JVM needs more memory than interpreted languages (256Mi-512Mi)
- **Liveness probe disabled:** Prevents pod restart when paused at breakpoint
- **Readiness probe enabled:** Uses Spring Actuator health endpoint
- **JAVA_OPTS:** Critical for JDWP activation

### 3.2 Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: java-spring-boot
  labels:
    app: java-spring-boot
spec:
  selector:
    app: java-spring-boot
  ports:
  - name: http
    port: 8080
    targetPort: 8080
    protocol: TCP
  - name: debug
    port: 5005
    targetPort: 5005
    protocol: TCP
  type: ClusterIP
```

## Phase 4: VS Code Configuration

### 4.1 Extensions

```json
{
  "recommendations": [
    "vscjava.vscode-java-pack",
    "vscjava.vscode-java-debug",
    "vscjava.vscode-maven",
    "ms-kubernetes-tools.vscode-kubernetes-tools"
  ]
}
```

**Java Extension Pack includes:**
- Language Support for Java (Red Hat)
- Debugger for Java
- Maven for Java
- Project Manager for Java
- IntelliCode

### 4.2 Launch Configuration

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Attach to Remote Pod",
      "type": "java",
      "request": "attach",
      "hostName": "localhost",
      "port": 5005,
      "projectName": "demo"
    }
  ]
}
```

**Simple configuration:**
- No path mapping needed (Java Extension handles this)
- Just hostname and port
- `projectName` should match Maven `<artifactId>`

### 4.3 Tasks

```json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "maven-build",
      "type": "shell",
      "command": "./mvnw clean package -DskipTests",
      "problemMatcher": []
    },
    {
      "label": "docker-build",
      "type": "shell",
      "command": "./manage.sh build",
      "problemMatcher": []
    },
    {
      "label": "deploy",
      "type": "shell",
      "command": "./manage.sh deploy",
      "problemMatcher": []
    },
    {
      "label": "port-forward-debug",
      "type": "shell",
      "command": "./manage.sh port-forward-debug",
      "problemMatcher": [],
      "isBackground": true
    }
  ]
}
```

## Phase 5: Management Script

### 5.1 Commands

Standard commands from shared infrastructure:
- `build` - Build Docker image with Maven
- `push` - Push to registry
- `deploy` - Deploy to namespace
- `debug` - Verify pod ready and port-forward JDWP port
- `port-forward` - Port-forward application port
- `port-forward-debug` - Port-forward debug port only
- `logs` - View pod logs
- `delete` - Delete from namespace
- `shell` - Exec into pod
- `restart` - Restart deployment
- `status` - Show deployment status

### 5.2 Example Implementation

```bash
#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR}/../.."

source "${ROOT_DIR}/shared/scripts/common-functions.sh"
export COMMON_SOURCED=1

source "${ROOT_DIR}/shared/scripts/k8s-helpers.sh"
export K8S_SOURCED=1

readonly VERSION="0.1.0"
readonly SCRIPT_NAME=$(basename "$0")
readonly APP_NAME="java-spring-boot"
readonly IMAGE_NAME="java-spring-boot"

IMAGE_TAG="${IMAGE_TAG:-latest}"
REGISTRY="${REGISTRY:-}"

cmd_build() {
    log_info "Building Docker image: ${IMAGE_NAME}:${IMAGE_TAG}"

    local full_image_name="${IMAGE_NAME}:${IMAGE_TAG}"
    if [ -n "$REGISTRY" ]; then
        full_image_name="${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
    fi

    docker build \
        -t "${full_image_name}" \
        -f "${SCRIPT_DIR}/Dockerfile" \
        "${SCRIPT_DIR}"

    log_success "Image built: ${full_image_name}"
}

cmd_debug() {
    require_namespace
    check_kubectl

    log_info "Setting up Java debugging with JDWP..."

    local pod_name="${POD_NAME:-}"
    if [ -z "$pod_name" ]; then
        pod_name=$(get_pod_name "$NAMESPACE" "$APP_NAME")
        log_info "Auto-detected pod: $pod_name"
    fi

    log_info "Port-forwarding JDWP debug port 5005..."
    port_forward_pod "$NAMESPACE" "$pod_name" "5005" "5005"
}

# ... (other commands following existing patterns)
```

## Phase 6: Documentation

### 6.1 README Structure

Following pattern from existing examples:

1. **Overview**
   - What this example demonstrates
   - Java/Spring Boot/JDWP versions
   - Debug method (port-forward to 5005)

2. **Prerequisites**
   - Kubernetes cluster
   - kubectl configured
   - Docker
   - VS Code with Java Extension Pack
   - Maven 3.6+ (for local builds)

3. **Quick Start**
   - Build, push, deploy commands
   - Port-forward and attach debugger

4. **Project Structure**
   - File tree with descriptions

5. **Building the Docker Image**
   - Multi-stage build explanation
   - JAVA_OPTS configuration

6. **Deploying to Kubernetes**
   - Deployment steps
   - Environment variable configuration

7. **Setting Up Remote Debugging**
   - Port-forward to 5005
   - VS Code attach steps
   - F5 to start debugging

8. **Debugging Walkthrough**
   - Test endpoints
   - Set breakpoints in controller methods
   - Variable inspection
   - Step through code

9. **Spring Boot-Specific Debugging Features**
   - Inspecting @Autowired beans
   - Request/Response objects
   - Exception breakpoints
   - Conditional breakpoints on Spring annotations

10. **Application Endpoints**
    - Table of endpoints with descriptions

11. **Spring Boot Framework Notes**
    - Dependency injection
    - Auto-configuration
    - Actuator endpoints

12. **VS Code Extensions**
    - Java Extension Pack details

13. **Management Commands**
    - All manage.sh commands documented

14. **Troubleshooting**
    - JDWP connection issues
    - Breakpoint not hitting
    - Pod crashes (OOM errors common in Java)
    - Port forwarding drops

15. **Configuration Details**
    - JDWP parameters explained
    - Kubernetes labels
    - Resource requests/limits for JVM

16. **VS Code Debug Configuration**
    - launch.json explanation
    - Why it's simpler than other languages

17. **Difference from Other Language Debugging**
    - Comparison table (vs .NET, Node.js, Python, Go)
    - JDWP advantages (mature, no code changes, built-in)

18. **References**
    - Spring Boot documentation
    - JDWP specification
    - VS Code Java debugging docs

## Complexity Analysis

### Comparison with Implemented Languages

| Aspect | C#/F# | Node.js | Python | Go | **Java** |
|--------|-------|---------|--------|-----|----------|
| Code changes | ❌ None | ❌ None | ❌ None | ❌ None | ❌ None |
| Build config | ❌ None | ❌ None | ❌ None | ✅ Flags | ✅ Env var |
| Debugger install | ✅ vsdbg | ✅ Built-in | ✅ debugpy | ✅ Delve | ✅ **Built-in JVM** |
| VS Code config | 🟡 Medium | 🟢 Simple | 🟢 Simple | 🟡 Medium | 🟢 **Simple** |
| Path mapping | 🟡 Manual | 🟢 Simple | 🟢 Simple | 🔴 Complex | 🟢 **Automatic** |
| Debug method | kubectl exec | Port-forward | Port-forward | Port-forward | Port-forward |
| Binary size | Medium | Small | Small | Medium | 🟡 Large |
| Memory usage | Low | Low | Low | Low | 🟡 **High (JVM)** |
| Setup time | 15 min | 10 min | 10 min | 20 min | **15 min** |

**Java advantages:**
- ✅ JDWP built into JVM (no installation)
- ✅ Mature debugging protocol (20+ years)
- ✅ VS Code Java Extension handles path mapping automatically
- ✅ No code changes needed
- ✅ Enterprise-proven debugging

**Java considerations:**
- ⚠️ Higher memory requirements (JVM heap + metaspace)
- ⚠️ Larger images (OpenJDK base image ~200MB)
- ⚠️ Slower startup than interpreted languages
- ⚠️ More resource requests needed (256Mi-512Mi RAM)

## Common Challenges & Solutions

### 1. Java 9+ Address Binding

**Problem:** Before Java 9, `address=5005` bound to all interfaces. Java 9+ only binds to localhost by default.

**Solution:** Use `address=*:5005` for Java 9+

### 2. Memory Limits

**Problem:** JVM can exceed Kubernetes memory limits and get OOMKilled.

**Solution:** Set JVM max heap size:
```yaml
env:
- name: JAVA_OPTS
  value: "-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:5005 -Xmx384m"
```

Rule of thumb: `Xmx` = 75% of container memory limit

### 3. Liveness Probe During Debugging

**Problem:** Same as other languages - pod killed when paused at breakpoint.

**Solution:** Disable liveness probe, keep readiness probe.

### 4. Spring Boot DevTools Conflict

**Problem:** Spring Boot DevTools can interfere with JDWP.

**Solution:** Exclude DevTools from production builds:
```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-devtools</artifactId>
    <scope>runtime</scope>
    <optional>true</optional>
</dependency>
```

### 5. Maven Build in Docker

**Problem:** Maven downloads dependencies every build (slow).

**Solution:** Multi-stage build with dependency caching layer (shown above).

## Success Criteria

- [ ] Spring Boot application with 3 endpoints (/health, /debug-test, /weatherforecast)
- [ ] Docker image builds with Maven multi-stage build
- [ ] JDWP enabled and listening on port 5005
- [ ] Kubernetes deployment succeeds
- [ ] Pod becomes ready (readiness probe passes)
- [ ] Port-forward to debug port works
- [ ] VS Code Java Extension connects
- [ ] Breakpoints set and hit in controller methods
- [ ] Variable inspection works (including Spring beans)
- [ ] Step debugging functions correctly
- [ ] Hot code replacement works (optional, nice to have)
- [ ] Documentation covers Spring Boot specifics
- [ ] Troubleshooting section addresses common JVM issues
- [ ] Tested with both Java 17 and 21

## Implementation Timeline

**Day 1:**
- Morning: Create Spring Boot application with 3 endpoints
- Afternoon: Create Dockerfile and test local build
- Evening: Create Kubernetes manifests

**Day 2:**
- Morning: Create VS Code configuration and test debugging locally
- Afternoon: Deploy to cluster and test remote debugging
- Evening: Create manage.sh script

**Day 3:**
- Morning: Write comprehensive README
- Afternoon: Test complete workflow, troubleshoot issues
- Evening: Document findings, update development-phases.md

**Total:** 2-3 days (depending on issues encountered)

## References

- [Spring Boot Documentation](https://spring.io/projects/spring-boot)
- [JDWP Specification](https://docs.oracle.com/javase/8/docs/technotes/guides/jpda/jdwp-spec.html)
- [VS Code Java Debugging](https://code.visualstudio.com/docs/java/java-debugging)
- [Remote Debug Spring Boot in Kubernetes](https://www.urosht.dev/blog/remote-debug-spring-boot-app-kubernetes/)
- [Baeldung: Spring Debugging](https://www.baeldung.com/spring-debugging)
- [Eclipse Temurin (OpenJDK)](https://adoptium.net/)

## Next Steps

1. ✅ Complete this planning document
2. Create `examples/java-spring-boot/` directory structure
3. Initialize Spring Boot project (via Spring Initializr or manual)
4. Implement endpoints
5. Create Dockerfile
6. Test local Docker build
7. Create Kubernetes manifests
8. Create VS Code configuration
9. Build, push, deploy
10. Test debugging workflow
11. Write README
12. Update development-phases.md

---

**Ready to proceed with implementation.**