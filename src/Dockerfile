# syntax=docker/dockerfile:1
FROM golang:1.21-alpine AS builder
ARG TARGETARCH
ARG TARGETOS
WORKDIR /src
COPY go.mod go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod \
    go mod download
COPY . .
RUN --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH go build -a -o http-echo main.go

FROM gcr.io/distroless/static:nonroot-$TARGETARCH
WORKDIR /
COPY --from=builder /src/http-echo .
EXPOSE 8080
ENTRYPOINT ["/http-echo"]
