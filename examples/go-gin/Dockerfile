FROM golang:1.23-alpine AS builder

WORKDIR /build

RUN apk add --no-cache git

COPY go.mod go.sum ./
RUN go mod download

COPY main.go ./

RUN go build -gcflags="all=-N -l" -o app main.go

RUN go install github.com/go-delve/delve/cmd/dlv@latest

FROM alpine:latest

RUN apk add --no-cache libc6-compat

WORKDIR /app

COPY --from=builder /build/app .
COPY --from=builder /go/bin/dlv /usr/local/bin/dlv

EXPOSE 8080 2345

CMD ["/usr/local/bin/dlv", "--listen=:2345", "--headless=true", "--api-version=2", "--accept-multiclient", "exec", "--continue", "/app/app"]